import 'dart:async';
import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import 'api/api_service.dart';
import 'session/session_manager.dart';
import 'socket/socket_service.dart';
import 'storage/private_key_storage.dart';
import 'sync/sync_service.dart';

class AppInitService extends ChangeNotifier {
  AppInitService._();
  static final AppInitService instance = AppInitService._();

  bool _isInitialized = false;
  bool _isBackendAvailable = false;
  bool _isConnectingBackend = false;
  bool _hasCompletedInitialSync = false;
  String? _currentWallet;
  String? _lastError;
  Timer? _reconnectTimer;

  bool get isInitialized => _isInitialized;
  bool get isBackendAvailable => _isBackendAvailable;
  bool get isOfflineMode => _isInitialized && !_isBackendAvailable;
  bool get isConnectingBackend => _isConnectingBackend;
  String? get currentWalletAddress => _currentWallet;
  String? get lastError => _lastError;

  Future<void> initializeForUser(String walletAddress) async {
    if (_isInitialized && _currentWallet == walletAddress) {
      await ensureBackendReady();
      return;
    }

    final privateKey = await PrivateKeyStorage.instance.loadPrivateKey(
      walletAddress,
    );
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('No private key found for wallet: $walletAddress');
    }

    await DbService.instance.openUserDatabase(walletAddress);

    _currentWallet = walletAddress;
    _isInitialized = true;
    notifyListeners();

    final backendReady = await _initializeBackendLayer(
      walletAddress: walletAddress,
      privateKey: privateKey,
    );

    if (!backendReady) {
      _scheduleReconnect();
    }

    debugPrint(
      '[AppInitService] Initialized for $walletAddress'
      '${backendReady ? ' with backend' : ' in offline mode'}',
    );
  }

  Future<bool> initializeFromSession() async {
    try {
      final walletAddress = await SessionManager.instance.getUserAddress();
      if (walletAddress == null) return false;
      await initializeForUser(walletAddress);
      return true;
    } catch (e) {
      debugPrint('[AppInitService] Failed to initialize from session: $e');
      return false;
    }
  }

  Future<bool> ensureBackendReady({bool runFullSync = true}) async {
    final walletAddress = _currentWallet;
    if (!_isInitialized || walletAddress == null) {
      return false;
    }

    if (_isBackendAvailable &&
        ApiService.instance.isInitialized &&
        (SocketService.instance.isConnected || !runFullSync)) {
      return true;
    }

    final privateKey = await PrivateKeyStorage.instance.loadPrivateKey(
      walletAddress,
    );
    if (privateKey == null || privateKey.isEmpty) {
      _setBackendAvailability(
        false,
        'No private key found for wallet: $walletAddress',
      );
      return false;
    }

    final ready = await _initializeBackendLayer(
      walletAddress: walletAddress,
      privateKey: privateKey,
      runFullSync: runFullSync,
    );

    if (!ready) {
      _scheduleReconnect();
    }

    return ready;
  }

  Future<bool> _initializeBackendLayer({
    required String walletAddress,
    required String privateKey,
    bool runFullSync = true,
  }) async {
    if (_isConnectingBackend) {
      return _isBackendAvailable;
    }

    _isConnectingBackend = true;
    notifyListeners();

    try {
      await ApiService.instance.initialize(
        walletAddress: walletAddress,
        privateKey: privateKey,
      );
      await SocketService.instance.connect(
        sessionToken: ApiService.instance.sessionToken,
      );
      SocketService.instance.startPing();

      if (runFullSync || !_hasCompletedInitialSync) {
        await SyncService.instance.performInitialSync();
        _hasCompletedInitialSync = true;
      }

      if (runFullSync) {
        await SyncService.instance.retryPendingMessages();
      }
      _setBackendAvailability(true, null);
      _reconnectTimer?.cancel();
      return true;
    } catch (e) {
      debugPrint('[AppInitService] Backend initialization unavailable: $e');
      _setBackendAvailability(false, e.toString());
      return false;
    } finally {
      _isConnectingBackend = false;
      notifyListeners();
    }
  }

  void _setBackendAvailability(bool isAvailable, String? error) {
    _isBackendAvailable = isAvailable;
    _lastError = error;
    notifyListeners();
  }

  void _scheduleReconnect() {
    if (_currentWallet == null) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      final ready = await ensureBackendReady();
      if (ready) {
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
      }
    });
  }

  @override
  void dispose() {
    unawaited(shutdown());
    super.dispose();
  }

  Future<void> shutdown() async {
    try {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      await SyncService.instance.dispose();
      SocketService.instance.stopPing();
      await ApiService.instance.dispose();
      await SocketService.instance.disconnect();
      await DbService.instance.closeUserDatabase();
    } finally {
      _isInitialized = false;
      _isBackendAvailable = false;
      _isConnectingBackend = false;
      _hasCompletedInitialSync = false;
      _currentWallet = null;
      _lastError = null;
    }
  }
}
