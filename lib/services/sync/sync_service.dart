import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xmtp/xmtp.dart' as xmtp;
import '../xmtp/xmtp_service.dart';
import '../../db/db_service.dart';
import '../../db/models/message_model.dart';
import '../../db/models/conversation_model.dart';

/// Sync Service - Syncs XMTP messages to local database
///
/// This is the heart of the offline-first architecture.
/// Handles:
/// - Initial sync from XMTP to local DB
/// - Real-time message streaming
/// - Deduplication using message IDs
/// - Automatic contact creation
class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final _xmtpService = XmtpService.instance;
  final _dbService = DbService.instance;

  StreamSubscription<xmtp.DecodedMessage>? _messageSubscription;
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIAL SYNC
  // ─────────────────────────────────────────────────────────────────────────

  /// Perform initial sync from XMTP to local database
  ///
  /// This fetches all conversations and messages from XMTP and stores them locally
  /// Should be called after XMTP client initialization
  Future<void> performInitialSync() async {
    if (_isSyncing) {
      debugPrint('[SyncService] Sync already in progress');
      return;
    }

    _isSyncing = true;
    debugPrint('[SyncService] Starting initial sync...');

    try {
      // Get all conversations from XMTP
      final xmtpConversations = await _xmtpService.listConversations();
      debugPrint(
        '[SyncService] Found ${xmtpConversations.length} conversations',
      );

      int totalMessages = 0;
      int newMessages = 0;

      // Process each conversation
      for (final xmtpConvo in xmtpConversations) {
        // Save conversation if not exists
        if (!_dbService.conversationExists(xmtpConvo.topic)) {
          final conversation = ConversationModel.fromXmtp(xmtpConvo);
          await _dbService.saveConversation(conversation);
          debugPrint(
            '[SyncService] Saved new conversation: ${xmtpConvo.topic}',
          );
        }

        // Get messages from this conversation
        final messages = await _xmtpService.getMessages(
          conversation: xmtpConvo,
          limit: 100, // Limit to last 100 messages for initial sync
        );

        totalMessages += messages.length;

        // Save messages to database (with deduplication)
        for (final xmtpMessage in messages) {
          if (!_dbService.messageExists(xmtpMessage.id)) {
            final message = MessageModel.fromXmtp(xmtpMessage, xmtpConvo.topic);
            await _dbService.saveMessage(message);
            newMessages++;

            // Update conversation's last message
            final conversation = _dbService.getConversation(xmtpConvo.topic);
            if (conversation != null) {
              conversation.updateLastMessage(message.content, message.sentAt);
            }

            // Auto-create contact
            await _dbService.upsertContact(xmtpMessage.sender.hex);
          }
        }
      }

      debugPrint('[SyncService] Initial sync complete');
      debugPrint('[SyncService] Total messages: $totalMessages');
      debugPrint('[SyncService] New messages saved: $newMessages');

      // Start real-time sync after initial sync
      startRealtimeSync();
    } catch (e, stackTrace) {
      debugPrint('[SyncService] Initial sync failed: $e');
      debugPrint('[SyncService] Stack trace: $stackTrace');
      rethrow;
    } finally {
      _isSyncing = false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAL-TIME SYNC
  // ─────────────────────────────────────────────────────────────────────────

  /// Start real-time message sync from XMTP stream
  ///
  /// Listens to XMTP message stream and saves new messages to database
  void startRealtimeSync() {
    if (_messageSubscription != null) {
      debugPrint('[SyncService] Real-time sync already active');
      return;
    }

    debugPrint('[SyncService] Starting real-time sync...');

    _messageSubscription = _xmtpService.messageStream.listen(
      (xmtpMessage) async {
        try {
          await _handleIncomingMessage(xmtpMessage);
        } catch (e) {
          debugPrint('[SyncService] Error handling incoming message: $e');
        }
      },
      onError: (error) {
        debugPrint('[SyncService] Stream error: $error');
      },
      onDone: () {
        debugPrint('[SyncService] Stream closed');
      },
    );

    debugPrint('[SyncService] Real-time sync started');
  }

  /// Stop real-time message sync
  Future<void> stopRealtimeSync() async {
    if (_messageSubscription != null) {
      await _messageSubscription!.cancel();
      _messageSubscription = null;
      debugPrint('[SyncService] Real-time sync stopped');
    }
  }

  /// Handle incoming message from XMTP stream
  Future<void> _handleIncomingMessage(xmtp.DecodedMessage xmtpMessage) async {
    debugPrint('[SyncService] Processing incoming message: ${xmtpMessage.id}');

    // Deduplication check
    if (_dbService.messageExists(xmtpMessage.id)) {
      debugPrint('[SyncService] Message already exists, skipping');
      return;
    }

    // We need to get the conversation topic
    // In a real app, you'd get this from the message or conversation list
    // For now, we'll create a synthetic topic from sender/recipient
    final conversations = await _xmtpService.listConversations();
    final matchingConvo = conversations.firstWhere(
      (c) => c.peer.hex == xmtpMessage.sender.hex,
      orElse: () => throw Exception('Conversation not found'),
    );

    // Save message to database
    final message = MessageModel.fromXmtp(xmtpMessage, matchingConvo.topic);
    await _dbService.saveMessage(message);

    // Update conversation
    var conversation = _dbService.getConversation(matchingConvo.topic);
    if (conversation == null) {
      conversation = ConversationModel.fromXmtp(matchingConvo);
      await _dbService.saveConversation(conversation);
    }
    conversation.updateLastMessage(message.content, message.sentAt);
    conversation.unreadCount++;
    await conversation.save();

    // Auto-create/update contact
    await _dbService.upsertContact(xmtpMessage.sender.hex);

    debugPrint('[SyncService] Message saved and synced');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SEND MESSAGE (with offline queue support)
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a message (saves locally first, then sends via XMTP)
  ///
  /// This implements the offline-first pattern:
  /// 1. Save message to local DB as "pending"
  /// 2. Send via XMTP
  /// 3. Update status to "sent" if successful
  Future<MessageModel> sendMessage({
    required String recipientAddress,
    required String messageContent,
  }) async {
    try {
      debugPrint('[SyncService] Sending message to: $recipientAddress');

      // Get or create conversation
      final xmtpConversation = await _xmtpService.getConversation(
        recipientAddress,
      );

      // Create message locally first (pending state)
      final localMessage = MessageModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        conversationTopic: xmtpConversation.topic,
        sender: _xmtpService.walletAddress ?? 'unknown',
        content: messageContent,
        sentAt: DateTime.now(),
        isSynced: false,
        status: 'pending',
      );

      // Save to local database
      await _dbService.saveMessage(localMessage);

      // Save/update conversation
      var conversation = _dbService.getConversation(xmtpConversation.topic);
      if (conversation == null) {
        conversation = ConversationModel.fromXmtp(xmtpConversation);
        await _dbService.saveConversation(conversation);
      }
      conversation.updateLastMessage(messageContent, DateTime.now());

      // Auto-create/update contact
      await _dbService.upsertContact(recipientAddress);

      // Attempt to send via XMTP
      try {
        await _xmtpService.sendMessage(
          recipientAddress: recipientAddress,
          message: messageContent,
        );

        // Update message status to sent
        await _dbService.updateMessageStatus(localMessage.id, true, 'sent');
        debugPrint('[SyncService] Message sent and synced');
      } catch (e) {
        // If send fails, keep as pending (will retry later)
        debugPrint('[SyncService] Failed to send message, kept as pending: $e');
        await _dbService.updateMessageStatus(localMessage.id, false, 'failed');
        rethrow;
      }

      return localMessage;
    } catch (e) {
      debugPrint('[SyncService] Send message error: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // OFFLINE QUEUE (Phase 6)
  // ─────────────────────────────────────────────────────────────────────────

  /// Retry sending pending messages
  ///
  /// This should be called when connection is restored
  Future<void> retryPendingMessages() async {
    debugPrint('[SyncService] Retrying pending messages...');

    final pendingMessages = _dbService.getPendingMessages();
    debugPrint(
      '[SyncService] Found ${pendingMessages.length} pending messages',
    );

    for (final message in pendingMessages) {
      try {
        // Get conversation to find peer address
        final conversation = _dbService.getConversation(
          message.conversationTopic,
        );
        if (conversation == null) {
          debugPrint(
            '[SyncService] Conversation not found for message: ${message.id}',
          );
          continue;
        }

        // Retry sending
        await _xmtpService.sendMessage(
          recipientAddress: conversation.peerAddress,
          message: message.content,
        );

        // Update status
        await _dbService.updateMessageStatus(message.id, true, 'sent');
        debugPrint('[SyncService] Pending message sent: ${message.id}');
      } catch (e) {
        debugPrint('[SyncService] Failed to retry message ${message.id}: $e');
        await _dbService.updateMessageStatus(message.id, false, 'failed');
      }
    }

    debugPrint('[SyncService] Retry complete');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Dispose and cleanup resources
  Future<void> dispose() async {
    await stopRealtimeSync();
    debugPrint('[SyncService] Disposed');
  }
}
