import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/message_model.dart';
import 'models/conversation_model.dart';
import 'models/contact_model.dart';

/// User-scoped database service using Hive
///
/// CRITICAL: Each user (wallet address) has their own isolated database boxes
/// This ensures complete data separation between users
class DbService {
  DbService._();
  static final DbService instance = DbService._();

  String? _currentWalletAddress;
  Box<MessageModel>? _messagesBox;
  Box<ConversationModel>? _conversationsBox;
  Box<ContactModel>? _contactsBox;

  bool get isInitialized => _currentWalletAddress != null;
  String? get currentWallet => _currentWalletAddress;

  /// Initialize Hive and register adapters
  ///
  /// Call this once at app startup
  static Future<void> initializeHive() async {
    await Hive.initFlutter();

    // Register Hive adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ContactModelAdapter());
    }

    debugPrint('[DbService] Hive initialized');
  }

  /// Open user-specific database boxes
  ///
  /// Opens boxes for messages, conversations, and contacts scoped to the wallet address
  Future<void> openUserDatabase(String walletAddress) async {
    if (_currentWalletAddress == walletAddress && isInitialized) {
      debugPrint(
        '[DbService] Database already open for wallet: $walletAddress',
      );
      return;
    }

    // Close existing boxes if any
    await closeUserDatabase();

    try {
      final wallet = walletAddress.toLowerCase();
      debugPrint('[DbService] Opening database for wallet: $wallet');

      // Open user-scoped boxes
      _messagesBox = await Hive.openBox<MessageModel>('messages_$wallet');
      _conversationsBox = await Hive.openBox<ConversationModel>(
        'conversations_$wallet',
      );
      _contactsBox = await Hive.openBox<ContactModel>('contacts_$wallet');

      _currentWalletAddress = wallet;

      debugPrint('[DbService] Database opened successfully');
      debugPrint('[DbService] Messages: ${_messagesBox!.length}');
      debugPrint('[DbService] Conversations: ${_conversationsBox!.length}');
      debugPrint('[DbService] Contacts: ${_contactsBox!.length}');
    } catch (e) {
      debugPrint('[DbService] Failed to open database: $e');
      _currentWalletAddress = null;
      rethrow;
    }
  }

  /// Close current user database
  Future<void> closeUserDatabase() async {
    if (!isInitialized) return;

    try {
      debugPrint(
        '[DbService] Closing database for wallet: $_currentWalletAddress',
      );

      await _messagesBox?.close();
      await _conversationsBox?.close();
      await _contactsBox?.close();

      _messagesBox = null;
      _conversationsBox = null;
      _contactsBox = null;
      _currentWalletAddress = null;

      debugPrint('[DbService] Database closed');
    } catch (e) {
      debugPrint('[DbService] Error closing database: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGE OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Save a message to the database
  Future<void> saveMessage(MessageModel message) async {
    _ensureInitialized();
    try {
      await _messagesBox!.put(message.id, message);
      debugPrint('[DbService] Message saved: ${message.id}');
    } catch (e) {
      debugPrint('[DbService] Failed to save message: $e');
      rethrow;
    }
  }

  /// Get all messages for a conversation
  List<MessageModel> getMessagesForConversation(String conversationTopic) {
    _ensureInitialized();
    return _messagesBox!.values
        .where((msg) => msg.conversationTopic == conversationTopic)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  /// Check if message exists
  bool messageExists(String messageId) {
    _ensureInitialized();
    return _messagesBox!.containsKey(messageId);
  }

  /// Get all messages
  List<MessageModel> getAllMessages() {
    _ensureInitialized();
    return _messagesBox!.values.toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  /// Get pending messages (not synced yet)
  List<MessageModel> getPendingMessages() {
    _ensureInitialized();
    return _messagesBox!.values.where((msg) => !msg.isSynced).toList();
  }

  /// Update message sync status
  Future<void> updateMessageStatus(
    String messageId,
    bool isSynced,
    String status,
  ) async {
    _ensureInitialized();
    final message = _messagesBox!.get(messageId);
    if (message != null) {
      message.isSynced = isSynced;
      message.status = status;
      await message.save();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVERSATION OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Save a conversation
  Future<void> saveConversation(ConversationModel conversation) async {
    _ensureInitialized();
    try {
      await _conversationsBox!.put(conversation.topic, conversation);
      debugPrint('[DbService] Conversation saved: ${conversation.topic}');
    } catch (e) {
      debugPrint('[DbService] Failed to save conversation: $e');
      rethrow;
    }
  }

  /// Get conversation by topic
  ConversationModel? getConversation(String topic) {
    _ensureInitialized();
    return _conversationsBox!.get(topic);
  }

  /// Get all conversations sorted by last message
  List<ConversationModel> getAllConversations() {
    _ensureInitialized();
    final conversations = _conversationsBox!.values.toList();
    conversations.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    return conversations;
  }

  /// Check if conversation exists
  bool conversationExists(String topic) {
    _ensureInitialized();
    return _conversationsBox!.containsKey(topic);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONTACT OPERATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// Save or update a contact
  Future<void> saveContact(ContactModel contact) async {
    _ensureInitialized();
    try {
      await _contactsBox!.put(contact.address.toLowerCase(), contact);
      debugPrint('[DbService] Contact saved: ${contact.address}');
    } catch (e) {
      debugPrint('[DbService] Failed to save contact: $e');
      rethrow;
    }
  }

  /// Get contact by address
  ContactModel? getContact(String address) {
    _ensureInitialized();
    return _contactsBox!.get(address.toLowerCase());
  }

  /// Get all contacts sorted by last interaction
  List<ContactModel> getAllContacts() {
    _ensureInitialized();
    final contacts = _contactsBox!.values.toList();
    contacts.sort((a, b) {
      if (a.lastInteractionAt == null) return 1;
      if (b.lastInteractionAt == null) return -1;
      return b.lastInteractionAt!.compareTo(a.lastInteractionAt!);
    });
    return contacts;
  }

  /// Upsert contact (create or update)
  Future<void> upsertContact(String address, {String? displayName}) async {
    _ensureInitialized();
    final existing = getContact(address);
    if (existing != null) {
      if (displayName != null) {
        existing.displayName = displayName;
      }
      existing.updateInteraction();
    } else {
      final contact = ContactModel(
        address: address.toLowerCase(),
        displayName: displayName,
        createdAt: DateTime.now(),
        lastInteractionAt: DateTime.now(),
      );
      await saveContact(contact);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Clear all data for current user (keep boxes open)
  Future<void> clearCurrentUserData() async {
    _ensureInitialized();
    await _messagesBox?.clear();
    await _conversationsBox?.clear();
    await _contactsBox?.clear();
    debugPrint('[DbService] All data cleared for current user');
  }

  /// Delete all data for a specific wallet (permanent)
  static Future<void> deleteUserData(String walletAddress) async {
    final wallet = walletAddress.toLowerCase();
    try {
      await Hive.deleteBoxFromDisk('messages_$wallet');
      await Hive.deleteBoxFromDisk('conversations_$wallet');
      await Hive.deleteBoxFromDisk('contacts_$wallet');
      debugPrint('[DbService] All data deleted for wallet: $wallet');
    } catch (e) {
      debugPrint('[DbService] Failed to delete user data: $e');
    }
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw Exception(
        'Database not initialized. Call openUserDatabase() first.',
      );
    }
  }
}
