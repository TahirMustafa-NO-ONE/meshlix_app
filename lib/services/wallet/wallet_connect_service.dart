import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:reown_appkit/reown_appkit.dart';

class WalletConnectService {
  WalletConnectService._();
  static final WalletConnectService instance = WalletConnectService._();

  ReownAppKitModal? _appKitModal;
  String? _connectedAddress;
  String? _lastWalletFilter; // Track the last wallet filter used

  bool get isConnected =>
      _appKitModal?.isConnected == true && _connectedAddress != null;
  String? get connectedAddress => _connectedAddress;

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURATION
  // Get your Project ID from https://cloud.reown.com (formerly walletconnect.com)
  // ─────────────────────────────────────────────────────────────────────────

  static String get _projectId =>
      dotenv.env['WALLETCONNECT_PROJECT_ID'] ?? 'YOUR_WALLETCONNECT_PROJECT_ID';

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    // AppKit Modal will be initialized when we have a BuildContext
    debugPrint('[WalletConnectService] Ready to initialize with context');
  }

  Future<void> _ensureInitialized(
    BuildContext context, {
    String? specificWalletId,
  }) async {
    // If modal exists but wallet filter changed AND not currently connected, dispose and recreate
    if (_appKitModal != null &&
        _lastWalletFilter != specificWalletId &&
        !isConnected) {
      dispose();
      _appKitModal = null;
    }

    if (_appKitModal != null) return;

    _lastWalletFilter = specificWalletId;

    try {
      // Configure which wallets to show based on selection
      Set<String>? includedWallets;
      Set<String>? featuredWallets;

      if (specificWalletId == 'metamask') {
        // Show ONLY MetaMask
        includedWallets = {
          'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96',
        };
        featuredWallets = includedWallets;
      } else if (specificWalletId == 'walletconnect') {
        // Show all wallets for QR code scanning
        featuredWallets = {
          'c57ca95b47569778a828d19178114f4db188b89b763c899ba0be274e97267d96', // MetaMask
        };
      }

      _appKitModal = ReownAppKitModal(
        context: context,
        projectId: _projectId,
        metadata: const PairingMetadata(
          name: 'Meshlix',
          description: 'Connect. Build. Deliver.',
          url: 'https://meshlix.app',
          icons: ['https://meshlix.app/logo.png'],
          redirect: Redirect(
            native: 'meshlix://',
            universal: 'https://meshlix.app',
          ),
        ),
        // Configure to show only specific wallets
        includedWalletIds: includedWallets,
        featuredWalletIds: featuredWallets ?? {},
      );

      await _appKitModal!.init();

      // Listen for connection events (subscribe once during initialization)
      _appKitModal!.onModalConnect.subscribe(_onModalConnect);
      _appKitModal!.onModalDisconnect.subscribe(_onModalDisconnect);
      _appKitModal!.onSessionUpdateEvent.subscribe(_onSessionUpdate);

      // Check if already connected after initialization
      _checkExistingConnection();

      debugPrint('[WalletConnectService] Initialized successfully');
    } on Object catch (e) {
      debugPrint('[WalletConnectService] Initialization failed: $e');
      rethrow;
    }
  }

  /// Check if there's an existing connection after initialization
  void _checkExistingConnection() {
    if (_appKitModal?.session != null && _connectedAddress == null) {
      final namespaces = _appKitModal!.session!.namespaces;
      final accounts = namespaces?['eip155']?.accounts ?? [];
      if (accounts.isNotEmpty) {
        _connectedAddress = accounts.first.split(':').last;
        debugPrint(
          '[WalletConnectService] Found existing connection: $_connectedAddress',
        );
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALLET CONNECTION
  // ─────────────────────────────────────────────────────────────────────────

  /// Connect to an external wallet using Reown AppKit (WalletConnect v2)
  ///
  /// [context] is required for showing the connection modal
  /// [walletId] optional specific wallet to connect to. If provided, modal shows only that wallet.
  /// Returns the connected Ethereum address
  Future<String> connectWallet(
    BuildContext context, {
    String? walletId,
  }) async {
    await _ensureInitialized(context, specificWalletId: walletId);

    if (_appKitModal == null) {
      throw Exception('WalletConnect not initialized. Initialization failed.');
    }

    // Check if already connected
    if (_appKitModal!.session != null && _connectedAddress != null) {
      debugPrint(
        '[WalletConnectService] Already connected: $_connectedAddress',
      );
      return _connectedAddress!;
    }

    try {
      // Open the modal (it will show only the specified wallet if walletId was provided)
      await _appKitModal!.openModalView();

      // Wait for connection to be established
      final completer = Completer<String>();
      Timer? timeoutTimer;
      Timer? checkTimer;

      void onConnect(ModalConnect? args) {
        if (!completer.isCompleted && _appKitModal!.session != null) {
          // Get address from the session
          final sessionData = _appKitModal!.session!;
          final namespaces = sessionData.namespaces;
          final accounts = namespaces?['eip155']?.accounts ?? [];

          if (accounts.isNotEmpty) {
            // Parse address from CAIP-10 format (e.g., 'eip155:1:0x123...')
            final address = accounts.first.split(':').last;
            _connectedAddress = address;
            timeoutTimer?.cancel();
            checkTimer?.cancel();

            // Close modal before completing to avoid UI blocking
            try {
              _appKitModal!.closeModal();
            } catch (_) {
              // Ignore errors when closing modal
            }

            completer.complete(address);
          }
        }
      }

      // Subscribe to connection events (temporary subscription for this connection attempt)
      _appKitModal!.onModalConnect.subscribe(onConnect);

      // Periodically check connection status (handles case where event doesn't fire)
      checkTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!completer.isCompleted) {
          _checkExistingConnection();
          if (_connectedAddress != null) {
            onConnect(null);
          }
        }
      });

      // Set timeout to 90 seconds (increased from 2 minutes to match reasonable user wait time)
      timeoutTimer = Timer(const Duration(seconds: 90), () {
        if (!completer.isCompleted) {
          checkTimer?.cancel();
          _appKitModal!.onModalConnect.unsubscribe(onConnect);

          // Close modal on timeout
          try {
            _appKitModal!.closeModal();
          } catch (_) {
            // Ignore errors when closing modal
          }

          completer.completeError(
            TimeoutException('Wallet connection timed out'),
          );
        }
      });

      try {
        final address = await completer.future;
        _appKitModal!.onModalConnect.unsubscribe(onConnect);
        debugPrint('[WalletConnectService] Connected to wallet: $address');
        return address;
      } catch (e) {
        _appKitModal!.onModalConnect.unsubscribe(onConnect);
        rethrow;
      }
    } on TimeoutException {
      throw Exception('Connection timed out. Please try again.');
    } on Object catch (e) {
      debugPrint('[WalletConnectService] Connection failed: $e');
      throw Exception('Failed to connect wallet: $e');
    }
  }

  /// Sign a message with the connected wallet
  ///
  /// Used to prove ownership of the wallet address
  Future<String> signMessage(String message) async {
    if (_appKitModal == null ||
        _connectedAddress == null ||
        _appKitModal!.session == null) {
      throw Exception('No wallet connected');
    }

    try {
      final result = await _appKitModal!.request(
        topic: _appKitModal!.session!.topic,
        chainId: 'eip155:1',
        request: SessionRequestParams(
          method: 'personal_sign',
          params: [message, _connectedAddress!],
        ),
      );

      return result.toString();
    } on Object catch (e) {
      debugPrint('[WalletConnectService] Message signing failed: $e');
      throw Exception('Failed to sign message: $e');
    }
  }

  /// Disconnect the current wallet session
  Future<void> disconnect() async {
    if (_appKitModal == null || !isConnected) return;

    try {
      await _appKitModal!.disconnect();
      _connectedAddress = null;
      debugPrint('[WalletConnectService] Disconnected');
    } on Object catch (e) {
      debugPrint('[WalletConnectService] Disconnect failed: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EVENT HANDLERS
  // ─────────────────────────────────────────────────────────────────────────

  void _onModalConnect(ModalConnect? event) {
    if (_appKitModal?.session != null) {
      final namespaces = _appKitModal!.session!.namespaces;
      final accounts = namespaces?['eip155']?.accounts ?? [];
      if (accounts.isNotEmpty) {
        _connectedAddress = accounts.first.split(':').last;
        debugPrint(
          '[WalletConnectService] Modal connected: $_connectedAddress',
        );
      }
    }
  }

  void _onModalDisconnect(ModalDisconnect? event) {
    debugPrint('[WalletConnectService] Modal disconnected');
    _connectedAddress = null;
  }

  void _onSessionUpdate(SessionUpdate? event) {
    debugPrint('[WalletConnectService] Session updated');
    if (_appKitModal?.session != null) {
      final namespaces = _appKitModal!.session!.namespaces;
      final accounts = namespaces?['eip155']?.accounts ?? [];
      if (accounts.isNotEmpty) {
        _connectedAddress = accounts.first.split(':').last;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // CLEANUP
  // ─────────────────────────────────────────────────────────────────────────

  void dispose() {
    _appKitModal?.onModalConnect.unsubscribe(_onModalConnect);
    _appKitModal?.onModalDisconnect.unsubscribe(_onModalDisconnect);
    _appKitModal?.onSessionUpdateEvent.unsubscribe(_onSessionUpdate);
  }
}
