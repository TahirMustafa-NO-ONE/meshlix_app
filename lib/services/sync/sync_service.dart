import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../db/db_service.dart';
import '../../db/models/conversation_model.dart';
import '../../db/models/message_model.dart';
import '../api/api_service.dart';
import '../socket/socket_service.dart';

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _apiService = ApiService.instance;
  final _socketService = SocketService.instance;
  final _dbService = DbService.instance;

  StreamSubscription<BackendMessage>? _messageSubscription;
  StreamSubscription<MessageStatus>? _statusSubscription;
  bool _isSyncing = false;

  bool get isSyncing => _isSyncing;

  Future<void> performInitialSync() async {
    if (_isSyncing) return;
    _isSyncing = true;

    try {
      final backendConversations = await _apiService.getConversations();

      for (final backendConvo in backendConversations) {
        if (await _dbService.isConversationDeleted(backendConvo.topic)) {
          continue;
        }

        if (!_dbService.conversationExists(backendConvo.topic)) {
          await _dbService.saveConversation(
            ConversationModel.fromBackend(backendConvo),
          );
        } else {
          await _dbService.updateConversationConsent(
            backendConvo.topic,
            backendConvo.consentState,
          );
        }

        final messages = await _apiService.getMessages(
          peerAddress: backendConvo.peerAddress,
        );

        for (final backendMessage in messages) {
          if (_dbService.messageExists(backendMessage.id)) {
            continue;
          }

          final message = MessageModel.fromBackend(
            backendMessage,
            backendConvo.topic,
          );
          await _dbService.saveMessage(message);
          await _dbService.upsertContact(backendConvo.peerAddress);

          final conversation = _dbService.getConversation(backendConvo.topic);
          if (conversation != null) {
            conversation.updateLastMessage(message.content, message.sentAt);
          }
        }
      }

      startRealtimeSync();
    } finally {
      _isSyncing = false;
    }
  }

  void startRealtimeSync() {
    if (_messageSubscription != null) return;

    _messageSubscription = _socketService.messageStream.listen((
      backendMessage,
    ) async {
      await _handleIncomingMessage(backendMessage);
    });

    _statusSubscription = _socketService.statusStream.listen((status) async {
      await _handleStatusUpdate(status);
    });
  }

  Future<void> stopRealtimeSync() async {
    await _messageSubscription?.cancel();
    await _statusSubscription?.cancel();
    _messageSubscription = null;
    _statusSubscription = null;
  }

  Future<void> _handleIncomingMessage(BackendMessage backendMessage) async {
    if (_dbService.messageExists(backendMessage.id)) {
      return;
    }

    final currentWallet = _apiService.walletAddress;
    if (currentWallet == null) {
      return;
    }

    final topic =
        backendMessage.conversationTopic ??
        generateConversationTopic(backendMessage.sender, currentWallet);
    if (await _dbService.isConversationDeleted(topic)) {
      return;
    }

    final message = MessageModel.fromBackend(backendMessage, topic);

    await _dbService.saveMessage(message);

    var conversation = _dbService.getConversation(topic);
    if (conversation == null) {
      conversation = ConversationModel(
        topic: topic,
        peerAddress: backendMessage.sender,
        createdAt: DateTime.now(),
        lastMessage: backendMessage.content,
        lastMessageAt: backendMessage.sentAt,
        unreadCount: 0,
        consentState: backendMessage.consentState,
      );
      await _dbService.saveConversation(conversation);
    }

    conversation.consentState = backendMessage.consentState;
    conversation.updateLastMessage(message.content, message.sentAt);
    conversation.unreadCount++;
    await conversation.save();
    await _dbService.upsertContact(conversation.peerAddress);
  }

  Future<void> _handleStatusUpdate(MessageStatus status) async {
    await _dbService.updateMessageStatus(
      status.id,
      status.status == 'sent',
      status.status,
    );
  }

  String generateConversationTopic(String addr1, String addr2) {
    final addresses = [addr1.toLowerCase(), addr2.toLowerCase()]..sort();
    return 'xmtp_${addresses[0]}_${addresses[1]}';
  }

  Future<MessageModel> sendMessage({
    required String recipientAddress,
    required String messageContent,
  }) async {
    final walletAddress = _apiService.walletAddress;
    if (walletAddress == null) {
      throw Exception('No active wallet session');
    }

    final topic = generateConversationTopic(recipientAddress, walletAddress);
    final temporaryId = 'local_${DateTime.now().microsecondsSinceEpoch}';
    final localMessage = MessageModel(
      id: temporaryId,
      conversationTopic: topic,
      sender: walletAddress,
      content: messageContent,
      sentAt: DateTime.now(),
      isSynced: false,
      status: 'pending',
    );

    await _dbService.saveMessage(localMessage);

    var conversation = _dbService.getConversation(topic);
    if (conversation == null) {
      conversation = ConversationModel(
        topic: topic,
        peerAddress: recipientAddress.toLowerCase(),
        createdAt: DateTime.now(),
        lastMessage: messageContent,
        lastMessageAt: localMessage.sentAt,
        consentState: 'allowed',
      );
      await _dbService.saveConversation(conversation);
    } else {
      conversation.consentState = 'allowed';
      conversation.updateLastMessage(messageContent, localMessage.sentAt);
    }

    await _dbService.upsertContact(recipientAddress);

    try {
      final sentMessage = await _apiService.sendMessage(
        recipientAddress: recipientAddress,
        message: messageContent,
      );
      await _dbService.replaceMessageId(
        oldId: temporaryId,
        newId: sentMessage.id,
        isSynced: true,
        status: sentMessage.status ?? 'sent',
      );
      localMessage.id = sentMessage.id;
      localMessage.isSynced = true;
      localMessage.status = sentMessage.status ?? 'sent';
      return localMessage;
    } catch (e) {
      await _dbService.updateMessageStatus(temporaryId, false, 'failed');
      rethrow;
    }
  }

  Future<void> retryPendingMessages() async {
    final pendingMessages = _dbService.getPendingMessages();

    for (final message in pendingMessages) {
      final conversation = _dbService.getConversation(
        message.conversationTopic,
      );
      if (conversation == null) {
        continue;
      }

      try {
        final sentMessage = await _apiService.sendMessage(
          recipientAddress: conversation.peerAddress,
          message: message.content,
        );
        await _dbService.replaceMessageId(
          oldId: message.id,
          newId: sentMessage.id,
          isSynced: true,
          status: sentMessage.status ?? 'sent',
        );
      } catch (e) {
        debugPrint('[SyncService] Retry failed for ${message.id}: $e');
        await _dbService.updateMessageStatus(message.id, false, 'failed');
      }
    }
  }

  Future<void> updateConversationConsent({
    required String peerAddress,
    required String consentState,
  }) async {
    final backendConversation = await _apiService.updateConversationConsent(
      peerAddress: peerAddress,
      consentState: consentState,
    );

    final existing = _dbService.getConversation(backendConversation.topic);
    if (existing != null) {
      existing.consentState = backendConversation.consentState;
      await existing.save();
      return;
    }

    await _dbService.saveConversation(
      ConversationModel.fromBackend(backendConversation),
    );
  }

  Future<void> dispose() async {
    await stopRealtimeSync();
  }
}
