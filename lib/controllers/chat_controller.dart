import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import '../db/models/message_model.dart';
import '../db/models/conversation_model.dart';
import '../db/models/contact_model.dart';
import '../services/sync/sync_service.dart';
import '../services/xmtp/xmtp_service.dart';

/// Chat Controller
///
/// Manages chat state and provides reactive updates to the UI.
/// This controller bridges the gap between services and UI components.
class ChatController extends ChangeNotifier {
  ChatController._();
  static final ChatController instance = ChatController._();

  final _dbService = DbService.instance;
  final _syncService = SyncService.instance;
  final _xmtpService = XmtpService.instance;

  // State
  List<ConversationModel> _conversations = [];
  List<ContactModel> _contacts = [];
  final Map<String, List<MessageModel>> _messagesByTopic = {};

  ConversationModel? _currentConversation;
  bool _isLoading = false;
  String? _error;

  // Getters
  List<ConversationModel> get conversations => _conversations;
  List<ContactModel> get contacts => _contacts;
  ConversationModel? get currentConversation => _currentConversation;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Get messages for current conversation
  List<MessageModel> get currentMessages {
    if (_currentConversation == null) return [];
    return _messagesByTopic[_currentConversation!.topic] ?? [];
  }

  /// Get messages for a specific conversation topic
  List<MessageModel> getMessagesForTopic(String topic) {
    return _messagesByTopic[topic] ?? [];
  }

  // Stream subscriptions
  StreamSubscription? _messageStreamSubscription;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Initialize controller and load data
  Future<void> initialize() async {
    debugPrint('[ChatController] Initializing...');
    _isLoading = true;
    notifyListeners();

    try {
      await loadConversations();
      await loadContacts();
      _startListeningToMessages();
      _error = null;
      debugPrint('[ChatController] Initialized successfully');
    } catch (e) {
      _error = e.toString();
      debugPrint('[ChatController] Initialization error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVERSATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Load all conversations from local database
  Future<void> loadConversations() async {
    try {
      _conversations = _dbService.getAllConversations();
      debugPrint(
        '[ChatController] Loaded ${_conversations.length} conversations',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatController] Error loading conversations: $e');
      rethrow;
    }
  }

  /// Set current conversation and load its messages
  Future<void> setCurrentConversation(ConversationModel conversation) async {
    _currentConversation = conversation;

    // Mark as read
    conversation.unreadCount = 0;
    await conversation.save();

    // Load messages for this conversation
    await loadMessagesForConversation(conversation.topic);
    notifyListeners();
  }

  /// Clear current conversation
  void clearCurrentConversation() {
    _currentConversation = null;
    notifyListeners();
  }

  /// Get or create a conversation with an address
  Future<ConversationModel?> getOrCreateConversation(String peerAddress) async {
    try {
      // Check if conversation already exists locally
      final existingConvo = _conversations.firstWhere(
        (c) => c.peerAddress.toLowerCase() == peerAddress.toLowerCase(),
        orElse: () => ConversationModel(
          topic: '',
          peerAddress: '',
          createdAt: DateTime.now(),
        ),
      );

      if (existingConvo.topic.isNotEmpty) {
        return existingConvo;
      }

      // Create new conversation via XMTP
      final xmtpConvo = await _xmtpService.getConversation(peerAddress);
      final conversation = ConversationModel.fromXmtp(xmtpConvo);

      // Save to database
      await _dbService.saveConversation(conversation);

      // Add to local list
      _conversations.insert(0, conversation);
      notifyListeners();

      return conversation;
    } catch (e) {
      debugPrint('[ChatController] Error creating conversation: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGES
  // ─────────────────────────────────────────────────────────────────────────

  /// Load messages for a specific conversation
  Future<void> loadMessagesForConversation(String topic) async {
    try {
      final messages = _dbService.getMessagesForConversation(topic);
      _messagesByTopic[topic] = messages;
      debugPrint(
        '[ChatController] Loaded ${messages.length} messages for $topic',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatController] Error loading messages: $e');
    }
  }

  /// Send a message to the current conversation
  Future<bool> sendMessage(String content) async {
    if (_currentConversation == null) {
      debugPrint('[ChatController] No current conversation');
      return false;
    }

    try {
      final message = await _syncService.sendMessage(
        recipientAddress: _currentConversation!.peerAddress,
        messageContent: content,
      );

      // Add to local list
      final messages = _messagesByTopic[_currentConversation!.topic] ?? [];
      messages.add(message);
      _messagesByTopic[_currentConversation!.topic] = messages;

      // Update conversation
      _currentConversation!.updateLastMessage(content, DateTime.now());

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[ChatController] Error sending message: $e');
      return false;
    }
  }

  /// Send a message to a specific address (creates conversation if needed)
  Future<bool> sendMessageToAddress(String address, String content) async {
    try {
      final conversation = await getOrCreateConversation(address);
      if (conversation == null) {
        return false;
      }

      await setCurrentConversation(conversation);
      return await sendMessage(content);
    } catch (e) {
      debugPrint('[ChatController] Error sending message to address: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTACTS
  // ─────────────────────────────────────────────────────────────────────────

  /// Load all contacts from local database
  Future<void> loadContacts() async {
    try {
      _contacts = _dbService.getAllContacts();
      debugPrint('[ChatController] Loaded ${_contacts.length} contacts');
      notifyListeners();
    } catch (e) {
      debugPrint('[ChatController] Error loading contacts: $e');
      rethrow;
    }
  }

  /// Add or update a contact
  Future<void> upsertContact(String address, {String? displayName}) async {
    try {
      await _dbService.upsertContact(address, displayName: displayName);
      await loadContacts();
    } catch (e) {
      debugPrint('[ChatController] Error upserting contact: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // REAL-TIME UPDATES
  // ─────────────────────────────────────────────────────────────────────────

  /// Start listening to incoming messages
  void _startListeningToMessages() {
    _messageStreamSubscription?.cancel();

    _messageStreamSubscription = _xmtpService.messageStream.listen(
      (xmtpMessage) async {
        debugPrint('[ChatController] New message received');

        // Reload conversations and messages
        await loadConversations();

        // If message is for current conversation, reload messages
        if (_currentConversation != null) {
          await loadMessagesForConversation(_currentConversation!.topic);
        }
      },
      onError: (error) {
        debugPrint('[ChatController] Message stream error: $error');
      },
    );
  }

  /// Refresh all data
  Future<void> refresh() async {
    await loadConversations();
    await loadContacts();
    if (_currentConversation != null) {
      await loadMessagesForConversation(_currentConversation!.topic);
    }
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Check if an address can receive messages
  Future<bool> canMessage(String address) async {
    try {
      return await _xmtpService.canMessage(address);
    } catch (e) {
      debugPrint('[ChatController] Error checking canMessage: $e');
      return false;
    }
  }

  /// Get total unread count across all conversations
  int get totalUnreadCount {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  /// Dispose resources
  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    super.dispose();
  }
}
