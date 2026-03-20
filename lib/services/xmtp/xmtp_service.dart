import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:xmtp/xmtp.dart' as xmtp;
import 'package:web3dart/web3dart.dart';
import '../session/session_manager.dart';
import 'xmtp_key_storage.dart';

/// XMTP Service - Handles peer-to-peer messaging using XMTP protocol
///
/// This service provides:
/// - Client initialization using private key from Web3Auth
/// - Sending messages to wallet addresses
/// - Receiving messages via streaming
/// - Listing conversations
///
/// Architecture note: XMTP is the transport layer only.
/// For production, sync to local DB for offline-first experience.
class XmtpService {
  XmtpService._();
  static final XmtpService instance = XmtpService._();

  xmtp.Client? _client;
  xmtp.Client? get client => _client;
  bool get isInitialized => _client != null;

  // Stream controllers for real-time message updates
  final _messageStreamController =
      StreamController<xmtp.DecodedMessage>.broadcast();
  Stream<xmtp.DecodedMessage> get messageStream =>
      _messageStreamController.stream;

  StreamSubscription<xmtp.DecodedMessage>? _messageSubscription;

  // ─────────────────────────────────────────────────────────────────────────
  // INITIALIZATION
  // ─────────────────────────────────────────────────────────────────────────

  /// Initialize XMTP client using the private key from SessionManager
  ///
  /// This method will:
  /// 1. Check if XMTP keys exist for this wallet
  /// 2. If yes, load keys and create client (faster, no signing needed)
  /// 3. If no, create new client from wallet and save keys
  ///
  /// [useProduction] - If true, uses production network, otherwise dev network
  /// Defaults to false (dev) for testing
  /// [walletAddress] - Optional wallet address (if not provided, gets from session)
  Future<void> initialize({
    bool useProduction = false,
    String? walletAddress,
  }) async {
    if (_client != null) {
      debugPrint('[XmtpService] Client already initialized');
      return;
    }

    // Get wallet address
    final wallet = walletAddress ?? await SessionManager.instance.getUserAddress();
    if (wallet == null) {
      throw Exception('No wallet address found. User must be authenticated first.');
    }

    try {
      // Determine host based on environment
      final host = useProduction ? 'production.xmtp.network' : 'dev.xmtp.network';

      debugPrint('[XmtpService] Initializing XMTP client...');
      debugPrint('[XmtpService] Network: $host');
      debugPrint('[XmtpService] Wallet: $wallet');

      // Create API client with host
      final api = xmtp.Api.create(host: host, isSecure: true);

      // Check if we have stored keys for this wallet
      final hasStoredKeys = await XmtpKeyStorage.instance.hasKeys(wallet);

      if (hasStoredKeys) {
        // Load from stored keys (fast, no signing needed)
        debugPrint('[XmtpService] Loading from stored keys...');
        await _initializeFromStoredKeys(api, wallet);
      } else {
        // Create new client from wallet (requires signing)
        debugPrint('[XmtpService] Creating new XMTP identity...');
        await _initializeFromWallet(api, wallet);
      }

      debugPrint('[XmtpService] XMTP client initialized successfully');
      debugPrint('[XmtpService] Wallet address: ${_client!.address}');

      // Start listening to incoming messages
      _startMessageStream();
    } catch (e, stackTrace) {
      debugPrint('[XmtpService] Failed to initialize XMTP client: $e');
      debugPrint('[XmtpService] Stack trace: $stackTrace');
      _client = null;
      rethrow;
    }
  }

  /// Initialize client from stored XMTP keys
  Future<void> _initializeFromStoredKeys(xmtp.Api api, String wallet) async {
    final keysData = await XmtpKeyStorage.instance.loadKeys(wallet);
    if (keysData == null) {
      throw Exception('No keys found for wallet');
    }

    // Decode base64 string to bytes
    final keysBytes = base64Decode(keysData);

    // Create PrivateKeyBundle from bytes
    final keys = xmtp.PrivateKeyBundle.fromBuffer(keysBytes);

    // Create client from keys
    _client = await xmtp.Client.createFromKeys(api, keys);

    debugPrint('[XmtpService] Client created from stored keys');
  }

  /// Initialize client from wallet private key (creates new XMTP identity)
  Future<void> _initializeFromWallet(xmtp.Api api, String wallet) async {
    // Get private key from session manager
    final privateKey = await SessionManager.instance.getAuthToken();
    if (privateKey == null) {
      throw Exception('No private key found. User must be authenticated first.');
    }

    // Create wallet from private key
    // Remove '0x' prefix if present
    final cleanedKey =
        privateKey.startsWith('0x') ? privateKey.substring(2) : privateKey;

    // Create EthPrivateKey wallet from web3dart
    final ethWallet = EthPrivateKey.fromHex(cleanedKey);

    // Create XMTP Signer using the wallet
    final signer = xmtp.Signer.create(
      ethWallet.address.hex,
      (text) async {
        final message = Uint8List.fromList(text.codeUnits);
        return ethWallet.signPersonalMessageToUint8List(message);
      },
    );

    // Create XMTP client
    _client = await xmtp.Client.createFromWallet(api, signer);

    // Save keys for future use
    final keysBytes = _client!.keys.writeToBuffer();
    final keysData = base64Encode(keysBytes);
    await XmtpKeyStorage.instance.saveKeys(
      walletAddress: wallet,
      keysData: keysData,
    );

    debugPrint('[XmtpService] Client created from wallet and keys saved');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MESSAGING
  // ─────────────────────────────────────────────────────────────────────────

  /// Send a text message to a wallet address
  ///
  /// [recipientAddress] - Ethereum wallet address (0x...)
  /// [message] - Text content to send
  ///
  /// Returns the sent message
  Future<String> sendMessage({
    required String recipientAddress,
    required String message,
  }) async {
    _ensureInitialized();

    try {
      debugPrint('[XmtpService] Sending message to: $recipientAddress');

      // Check if recipient can receive XMTP messages
      final canMessage = await _client!.canMessage(recipientAddress);
      if (!canMessage) {
        throw Exception(
          'Recipient $recipientAddress is not on the XMTP network. '
          'They must create an XMTP identity first.',
        );
      }

      // Get or create conversation with recipient
      final conversation = await _client!.newConversation(recipientAddress);

      // Send the message using the client method
      await _client!.sendMessage(conversation, message);

      debugPrint('[XmtpService] Message sent successfully');

      return 'Message sent to $recipientAddress';
    } catch (e, stackTrace) {
      debugPrint('[XmtpService] Failed to send message: $e');
      debugPrint('[XmtpService] Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get or create a conversation with a wallet address
  ///
  /// [peerAddress] - Ethereum wallet address of the peer
  Future<xmtp.Conversation> getConversation(String peerAddress) async {
    _ensureInitialized();

    try {
      final conversation = await _client!.newConversation(peerAddress);
      return conversation;
    } catch (e) {
      debugPrint('[XmtpService] Failed to get conversation: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // RECEIVING MESSAGES
  // ─────────────────────────────────────────────────────────────────────────

  /// Start streaming incoming messages across all conversations
  ///
  /// Messages will be broadcast through the messageStream
  void _startMessageStream() {
    _ensureInitialized();

    try {
      debugPrint('[XmtpService] Starting message stream...');

      // Start streaming conversations first, then stream messages from each
      _client!.streamConversations().listen(
        (conversation) async {
          debugPrint('[XmtpService] New conversation detected: ${conversation.peer}');

          // For each conversation, stream its messages
          final messageStream = _client!.streamMessages(conversation);
          messageStream.listen(
            (message) {
              debugPrint('[XmtpService] New message received');
              debugPrint('[XmtpService] From: ${message.sender}');
              debugPrint('[XmtpService] Content: ${message.content}');

              // Broadcast to listeners
              _messageStreamController.add(message);
            },
            onError: (error) {
              debugPrint('[XmtpService] Message stream error: $error');
            },
          );
        },
        onError: (error) {
          debugPrint('[XmtpService] Conversation stream error: $error');
        },
      );

      // Also stream messages from existing conversations
      _startStreamingExistingConversations();

      debugPrint('[XmtpService] Message stream started successfully');
    } catch (e) {
      debugPrint('[XmtpService] Failed to start message stream: $e');
      rethrow;
    }
  }

  /// Stream messages from all existing conversations
  Future<void> _startStreamingExistingConversations() async {
    try {
      final conversations = await _client!.listConversations();
      for (final conversation in conversations) {
        final messageStream = _client!.streamMessages(conversation);
        messageStream.listen(
          (message) {
            debugPrint('[XmtpService] Message from existing conversation');
            _messageStreamController.add(message);
          },
          onError: (error) {
            debugPrint('[XmtpService] Error streaming existing conversation: $error');
          },
        );
      }
    } catch (e) {
      debugPrint('[XmtpService] Error setting up existing conversation streams: $e');
    }
  }

  /// Stop streaming messages
  Future<void> stopMessageStream() async {
    if (_messageSubscription != null) {
      await _messageSubscription!.cancel();
      _messageSubscription = null;
      debugPrint('[XmtpService] Message stream stopped');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CONVERSATIONS
  // ─────────────────────────────────────────────────────────────────────────

  /// List all conversations
  ///
  /// Returns a list of all conversations the user has participated in
  Future<List<xmtp.Conversation>> listConversations() async {
    _ensureInitialized();

    try {
      debugPrint('[XmtpService] Fetching conversations...');
      final conversations = await _client!.listConversations();
      debugPrint('[XmtpService] Found ${conversations.length} conversations');
      return conversations;
    } catch (e) {
      debugPrint('[XmtpService] Failed to list conversations: $e');
      rethrow;
    }
  }

  /// Get all messages from a specific conversation
  ///
  /// [conversation] - The conversation to fetch messages from
  /// [limit] - Maximum number of messages to fetch (optional)
  /// [start] - Optional start date for filtering messages
  /// [end] - Optional end date for filtering messages
  Future<List<xmtp.DecodedMessage>> getMessages({
    required xmtp.Conversation conversation,
    int? limit,
    DateTime? start,
    DateTime? end,
  }) async {
    _ensureInitialized();

    try {
      debugPrint('[XmtpService] Fetching messages from conversation...');
      final messages = await _client!.listMessages(
        conversation,
        start: start,
        end: end,
        limit: limit,
      );
      debugPrint('[XmtpService] Found ${messages.length} messages');
      return messages;
    } catch (e) {
      debugPrint('[XmtpService] Failed to get messages: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // UTILITIES
  // ─────────────────────────────────────────────────────────────────────────

  /// Check if a wallet address can receive XMTP messages
  ///
  /// Returns true if the address has an XMTP identity
  Future<bool> canMessage(String address) async {
    _ensureInitialized();

    try {
      final result = await _client!.canMessage(address);
      debugPrint('[XmtpService] Can message $address: $result');
      return result;
    } catch (e) {
      debugPrint('[XmtpService] Failed to check if can message: $e');
      return false;
    }
  }

  /// Get the current user's wallet address
  String? get walletAddress => _client?.address.hex;

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  /// Dispose the service and cleanup resources
  Future<void> dispose() async {
    debugPrint('[XmtpService] Disposing service...');

    await stopMessageStream();

    if (!_messageStreamController.isClosed) {
      await _messageStreamController.close();
    }

    _client = null;
    debugPrint('[XmtpService] Service disposed');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  void _ensureInitialized() {
    if (_client == null) {
      throw Exception('XMTP client not initialized. Call initialize() first.');
    }
  }
}
