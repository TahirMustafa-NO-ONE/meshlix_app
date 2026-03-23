import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/contact_model.dart';
import 'models/conversation_model.dart';
import 'models/message_model.dart';

class DbService {
  DbService._();
  static final DbService instance = DbService._();

  String? _currentWalletAddress;
  Box<MessageModel>? _messagesBox;
  Box<ConversationModel>? _conversationsBox;
  Box<ContactModel>? _contactsBox;
  SharedPreferences? _prefs;

  bool get isInitialized => _currentWalletAddress != null;
  String? get currentWallet => _currentWalletAddress;

  static Future<void> initializeHive() async {
    await Hive.initFlutter();

    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(MessageModelAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ConversationModelAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ContactModelAdapter());
    }
  }

  Future<void> openUserDatabase(String walletAddress) async {
    if (_currentWalletAddress == walletAddress && isInitialized) {
      return;
    }

    await closeUserDatabase();

    final wallet = walletAddress.toLowerCase();
    _messagesBox = await Hive.openBox<MessageModel>('messages_$wallet');
    _conversationsBox = await Hive.openBox<ConversationModel>(
      'conversations_$wallet',
    );
    _contactsBox = await Hive.openBox<ContactModel>('contacts_$wallet');
    _prefs = await SharedPreferences.getInstance();
    _currentWalletAddress = wallet;
  }

  Future<void> closeUserDatabase() async {
    if (!isInitialized) return;

    await _messagesBox?.close();
    await _conversationsBox?.close();
    await _contactsBox?.close();

    _messagesBox = null;
    _conversationsBox = null;
    _contactsBox = null;
    _prefs = null;
    _currentWalletAddress = null;
  }

  Future<void> saveMessage(MessageModel message) async {
    _ensureInitialized();
    await _messagesBox!.put(message.id, message);
  }

  Future<void> replaceMessageId({
    required String oldId,
    required String newId,
    required bool isSynced,
    required String status,
  }) async {
    _ensureInitialized();
    final existing = _messagesBox!.get(oldId);
    if (existing == null) return;

    await _messagesBox!.delete(oldId);
    existing.id = newId;
    existing.isSynced = isSynced;
    existing.status = status;
    await _messagesBox!.put(newId, existing);
  }

  List<MessageModel> getMessagesForConversation(String conversationTopic) {
    _ensureInitialized();
    return _messagesBox!.values
        .where((msg) => msg.conversationTopic == conversationTopic)
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  bool messageExists(String messageId) {
    _ensureInitialized();
    return _messagesBox!.containsKey(messageId);
  }

  List<MessageModel> getPendingMessages() {
    _ensureInitialized();
    return _messagesBox!.values
        .where((msg) => !msg.isSynced || msg.status == 'failed')
        .toList()
      ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }

  Future<void> updateMessageStatus(
    String messageId,
    bool isSynced,
    String status,
  ) async {
    _ensureInitialized();
    final message = _messagesBox!.get(messageId);
    if (message == null) return;
    message.isSynced = isSynced;
    message.status = status;
    await message.save();
  }

  Future<void> saveConversation(ConversationModel conversation) async {
    _ensureInitialized();
    await _conversationsBox!.put(conversation.topic, conversation);
  }

  Future<void> deleteConversationData({
    required String topic,
    required String peerAddress,
  }) async {
    _ensureInitialized();

    final messageKeys = _messagesBox!.keys.where((key) {
      final message = _messagesBox!.get(key);
      return message?.conversationTopic == topic;
    }).toList();

    if (messageKeys.isNotEmpty) {
      await _messagesBox!.deleteAll(messageKeys);
    }

    await _conversationsBox!.delete(topic);

    final normalizedPeer = peerAddress.toLowerCase();
    final hasOtherConversation = _conversationsBox!.values.any(
      (conversation) =>
          conversation.peerAddress.toLowerCase() == normalizedPeer,
    );

    if (!hasOtherConversation) {
      await _contactsBox!.delete(normalizedPeer);
    }
  }

  ConversationModel? getConversation(String topic) {
    _ensureInitialized();
    return _conversationsBox!.get(topic);
  }

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

  List<ConversationModel> getConversationsByConsent(
    List<String> consentStates,
  ) {
    _ensureInitialized();
    final allowedStates = consentStates
        .map((state) => state.toLowerCase())
        .toSet();
    final conversations = _conversationsBox!.values
        .where(
          (conversation) => allowedStates.contains(conversation.consentState),
        )
        .toList();
    conversations.sort((a, b) {
      if (a.lastMessageAt == null) return 1;
      if (b.lastMessageAt == null) return -1;
      return b.lastMessageAt!.compareTo(a.lastMessageAt!);
    });
    return conversations;
  }

  bool conversationExists(String topic) {
    _ensureInitialized();
    return _conversationsBox!.containsKey(topic);
  }

  Future<void> updateConversationConsent(
    String topic,
    String consentState,
  ) async {
    _ensureInitialized();
    final conversation = _conversationsBox!.get(topic);
    if (conversation == null) return;
    conversation.consentState = consentState.toLowerCase();
    await conversation.save();
  }

  Future<void> saveContact(ContactModel contact) async {
    _ensureInitialized();
    await _contactsBox!.put(contact.address.toLowerCase(), contact);
  }

  Future<void> deleteContact(String address) async {
    _ensureInitialized();
    await _contactsBox!.delete(address.toLowerCase());
  }

  ContactModel? getContact(String address) {
    _ensureInitialized();
    return _contactsBox!.get(address.toLowerCase());
  }

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

  Future<void> upsertContact(String address, {String? displayName}) async {
    _ensureInitialized();
    final existing = getContact(address);
    if (existing != null) {
      if (displayName != null) {
        existing.displayName = displayName;
      }
      existing.updateInteraction();
      return;
    }

    await saveContact(
      ContactModel(
        address: address.toLowerCase(),
        displayName: displayName,
        createdAt: DateTime.now(),
        lastInteractionAt: DateTime.now(),
      ),
    );
  }

  Future<void> markConversationDeleted(String topic) async {
    _ensureInitialized();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedConversationKey()) ?? [];
    if (!deleted.contains(topic)) {
      await prefs.setStringList(_deletedConversationKey(), [...deleted, topic]);
    }
  }

  Future<void> unmarkConversationDeleted(String topic) async {
    _ensureInitialized();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedConversationKey()) ?? [];
    if (deleted.contains(topic)) {
      deleted.remove(topic);
      await prefs.setStringList(_deletedConversationKey(), deleted);
    }
  }

  Future<bool> isConversationDeleted(String topic) async {
    _ensureInitialized();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    final deleted = prefs.getStringList(_deletedConversationKey()) ?? [];
    return deleted.contains(topic);
  }

  String _deletedConversationKey() {
    return 'deleted_conversations_${_currentWalletAddress!}';
  }

  void _ensureInitialized() {
    if (!isInitialized) {
      throw Exception(
        'Database not initialized. Call openUserDatabase() first.',
      );
    }
  }
}
