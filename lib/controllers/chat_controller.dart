import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import '../db/models/contact_model.dart';
import '../db/models/conversation_model.dart';
import '../db/models/message_model.dart';
import '../services/api/api_service.dart';
import '../services/socket/socket_service.dart';
import '../services/sync/sync_service.dart';

class ChatController extends ChangeNotifier {
  ChatController._();
  static final ChatController instance = ChatController._();

  final _dbService = DbService.instance;
  final _syncService = SyncService.instance;

  List<ConversationModel> _conversations = [];
  List<ConversationModel> _requests = [];
  List<ContactModel> _contacts = [];
  final Map<String, List<MessageModel>> _messagesByTopic = {};
  ConversationModel? _currentConversation;
  bool _isLoading = false;
  String? _error;

  StreamSubscription<BackendMessage>? _messageStreamSubscription;
  StreamSubscription<MessageStatus>? _statusStreamSubscription;

  List<ConversationModel> get conversations => _conversations;
  List<ConversationModel> get requests => _requests;
  List<ContactModel> get contacts => _contacts;
  ConversationModel? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<MessageModel> get currentMessages {
    if (_currentConversation == null) return [];
    return _messagesByTopic[_currentConversation!.topic] ?? [];
  }

  List<MessageModel> getMessagesForTopic(String topic) {
    return _messagesByTopic[topic] ?? [];
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await loadConversations();
      await loadContacts();
      _startListeningToMessages();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadConversations() async {
    _conversations = _dbService.getConversationsByConsent(['allowed']);
    _requests = _dbService.getConversationsByConsent(['unknown']);
    notifyListeners();
  }

  Future<void> setCurrentConversation(ConversationModel conversation) async {
    _currentConversation = conversation;
    conversation.unreadCount = 0;
    await conversation.save();
    await loadMessagesForConversation(conversation.topic);
    notifyListeners();
  }

  void clearCurrentConversation() {
    _currentConversation = null;
    notifyListeners();
  }

  Future<ConversationModel?> getOrCreateConversation(String peerAddress) async {
    try {
      final existing = _conversations.where(
        (c) => c.peerAddress.toLowerCase() == peerAddress.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        return existing.first;
      }

      final currentWallet = ApiService.instance.walletAddress;
      if (currentWallet == null) {
        throw Exception('No active wallet session');
      }

      final topic = _syncService.generateConversationTopic(
        peerAddress,
        currentWallet,
      );
      final conversation = ConversationModel(
        topic: topic,
        peerAddress: peerAddress.toLowerCase(),
        createdAt: DateTime.now(),
        consentState: 'allowed',
      );
      await _dbService.saveConversation(conversation);
      await _dbService.upsertContact(peerAddress);
      _conversations.insert(0, conversation);
      notifyListeners();
      return conversation;
    } catch (e) {
      debugPrint('[ChatController] Error creating conversation: $e');
      return null;
    }
  }

  Future<void> loadMessagesForConversation(String topic) async {
    _messagesByTopic[topic] = _dbService.getMessagesForConversation(topic);
    notifyListeners();
  }

  Future<bool> sendMessage(String content) async {
    if (_currentConversation == null) {
      return false;
    }

    try {
      final topic = _currentConversation!.topic;
      final message = await _syncService.sendMessage(
        recipientAddress: _currentConversation!.peerAddress,
        messageContent: content,
      );

      final messages = _messagesByTopic[topic] ?? [];
      final alreadyPresent = messages.any(
        (existing) =>
            existing.id == message.id ||
            (existing.sentAt == message.sentAt &&
                existing.sender == message.sender &&
                existing.content == message.content),
      );

      if (!alreadyPresent) {
        messages.add(message);
        _messagesByTopic[topic] = messages;
      } else {
        await loadMessagesForConversation(topic);
      }

      _currentConversation!.updateLastMessage(content, message.sentAt);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ChatController] Error sending message: $e');
      return false;
    }
  }

  Future<bool> sendMessageToAddress(String address, String content) async {
    final conversation = await getOrCreateConversation(address);
    if (conversation == null) {
      return false;
    }

    await setCurrentConversation(conversation);
    return sendMessage(content);
  }

  Future<void> loadContacts() async {
    _contacts = _dbService.getAllContacts();
    notifyListeners();
  }

  Future<void> upsertContact(String address, {String? displayName}) async {
    await _dbService.upsertContact(address, displayName: displayName);
    await loadContacts();
  }

  void _startListeningToMessages() {
    _messageStreamSubscription?.cancel();
    _statusStreamSubscription?.cancel();

    _messageStreamSubscription = SocketService.instance.messageStream.listen((_) async {
      await refresh();
    });

    _statusStreamSubscription = SocketService.instance.statusStream.listen((_) async {
      if (_currentConversation != null) {
        await loadMessagesForConversation(_currentConversation!.topic);
      }
      await loadConversations();
    });
  }

  Future<void> refresh() async {
    await loadConversations();
    await loadContacts();
    if (_currentConversation != null) {
      await loadMessagesForConversation(_currentConversation!.topic);
    }
    notifyListeners();
  }

  Future<bool> canMessage(String address) {
    return ApiService.instance.canMessage(address);
  }

  int get totalUnreadCount {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  int get totalRequestCount => _requests.length;

  Future<void> acceptRequest(ConversationModel conversation) async {
    await _syncService.updateConversationConsent(
      peerAddress: conversation.peerAddress,
      consentState: 'allowed',
    );
    conversation.consentState = 'allowed';
    await refresh();
  }

  Future<void> declineRequest(ConversationModel conversation) async {
    await _syncService.updateConversationConsent(
      peerAddress: conversation.peerAddress,
      consentState: 'denied',
    );
    conversation.consentState = 'denied';
    await refresh();
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    _statusStreamSubscription?.cancel();
    super.dispose();
  }
}
