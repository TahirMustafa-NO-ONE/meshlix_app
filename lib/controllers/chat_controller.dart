import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import '../db/models/contact_model.dart';
import '../db/models/conversation_model.dart';
import '../db/models/message_model.dart';
import '../services/api/api_service.dart';
import '../services/app_init_service.dart';
import '../services/auth/auth_service.dart';
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
      await AppInitService.instance.ensureBackendReady();
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
    final allConversations = _dbService.getAllConversations();
    final walletAddress = _activeWalletAddress?.toLowerCase();

    _requests = allConversations
        .where(
          (conversation) => _isConnectionRequest(conversation, walletAddress),
        )
        .toList();
    _conversations = allConversations
        .where(
          (conversation) => !_isConnectionRequest(conversation, walletAddress),
        )
        .toList();
    notifyListeners();
  }

  Future<void> setCurrentConversation(ConversationModel conversation) async {
    _currentConversation = conversation;
    await markConversationAsRead(conversation.topic);
    await loadMessagesForConversation(conversation.topic);
    notifyListeners();
  }

  void clearCurrentConversation() {
    _currentConversation = null;
    notifyListeners();
  }

  Future<ConversationModel?> getOrCreateConversation(String peerAddress) async {
    try {
      final currentWallet = _activeWalletAddress;
      if (currentWallet == null) {
        throw Exception('No active wallet session');
      }

      final topic = _syncService.generateConversationTopic(
        peerAddress,
        currentWallet,
      );
      await _dbService.unmarkConversationDeleted(topic);
      await loadConversations();

      final existing = _conversations.where(
        (c) => c.peerAddress.toLowerCase() == peerAddress.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        return existing.first;
      }

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

  Future<void> markConversationAsRead(String topic) async {
    final conversation = _dbService.getConversation(topic);
    if (conversation == null) return;

    if (conversation.unreadCount != 0) {
      conversation.unreadCount = 0;
      await conversation.save();
    }

    if (_currentConversation?.topic == topic) {
      _currentConversation = conversation;
    }

    await loadConversations();
  }

  Future<void> deleteConversation(ConversationModel conversation) async {
    if (_currentConversation?.topic == conversation.topic) {
      _currentConversation = null;
    }

    _messagesByTopic.remove(conversation.topic);
    await _dbService.markConversationDeleted(conversation.topic);
    await _dbService.deleteConversationData(
      topic: conversation.topic,
      peerAddress: conversation.peerAddress,
    );
    await refresh();
  }

  Future<void> deleteContact(ContactModel contact) async {
    final currentWallet = _activeWalletAddress;
    if (currentWallet == null) {
      throw Exception('No active wallet session');
    }

    final topic = _syncService.generateConversationTopic(
      contact.address,
      currentWallet,
    );
    await _dbService.markConversationDeleted(topic);
    _messagesByTopic.remove(topic);

    if (_currentConversation?.topic == topic) {
      _currentConversation = null;
    }

    await _dbService.deleteConversationData(
      topic: topic,
      peerAddress: contact.address,
    );
    await _dbService.deleteContact(contact.address);
    await refresh();
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
      await loadConversations();
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

    _messageStreamSubscription = SocketService.instance.messageStream.listen((
      _,
    ) async {
      await refresh();
    });

    _statusStreamSubscription = SocketService.instance.statusStream.listen((
      _,
    ) async {
      if (_currentConversation != null) {
        await loadMessagesForConversation(_currentConversation!.topic);
      }
      await loadConversations();
    });
  }

  Future<void> refresh() async {
    await AppInitService.instance.ensureBackendReady();
    await loadConversations();
    await loadContacts();
    if (_currentConversation != null) {
      await markConversationAsRead(_currentConversation!.topic);
      await loadMessagesForConversation(_currentConversation!.topic);
    }
    notifyListeners();
  }

  Future<bool> canMessage(String address) {
    return _canMessageInternal(address);
  }

  int get totalUnreadCount {
    return _conversations.fold(0, (sum, c) => sum + c.unreadCount);
  }

  int get totalRequestCount => _requests.length;

  Future<void> acceptRequest(ConversationModel conversation) async {
    await setCurrentConversation(conversation);
  }

  Future<void> declineRequest(ConversationModel conversation) async {
    await deleteConversation(conversation);
  }

  bool isConnectionRequest(ConversationModel conversation) {
    final walletAddress = _activeWalletAddress?.toLowerCase();
    return _isConnectionRequest(conversation, walletAddress);
  }

  String? get _activeWalletAddress =>
      AppInitService.instance.currentWalletAddress ??
      ApiService.instance.walletAddress ??
      AuthService.instance.currentUser?.publicAddress;

  Future<bool> _canMessageInternal(String address) async {
    final ready = await AppInitService.instance.ensureBackendReady(
      runFullSync: false,
    );
    if (!ready) {
      return false;
    }
    return ApiService.instance.canMessage(address);
  }

  bool _isConnectionRequest(
    ConversationModel conversation,
    String? walletAddress,
  ) {
    if (walletAddress == null) return false;

    final messages = _dbService.getMessagesForConversation(conversation.topic);
    if (messages.isEmpty) return false;

    final hasOutgoingMessage = messages.any(
      (message) => message.sender.toLowerCase() == walletAddress,
    );
    final hasIncomingMessage = messages.any(
      (message) => message.sender.toLowerCase() != walletAddress,
    );

    return hasIncomingMessage && !hasOutgoingMessage;
  }

  @override
  void dispose() {
    _messageStreamSubscription?.cancel();
    _statusStreamSubscription?.cancel();
    super.dispose();
  }
}
