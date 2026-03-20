import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import 'api/api_service.dart';
import 'session/session_manager.dart';
import 'socket/socket_service.dart';
import 'storage/private_key_storage.dart';
import 'sync/sync_service.dart';

class AppInitService {
  AppInitService._();
  static final AppInitService instance = AppInitService._();

  bool _isInitialized = false;
  String? _currentWallet;

  bool get isInitialized => _isInitialized;

  Future<void> initializeForUser(String walletAddress) async {
    if (_isInitialized && _currentWallet == walletAddress) {
      return;
    }

    final privateKey = await PrivateKeyStorage.instance.loadPrivateKey(
      walletAddress,
    );
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('No private key found for wallet: $walletAddress');
    }

    await DbService.instance.openUserDatabase(walletAddress);
    await ApiService.instance.initialize(
      walletAddress: walletAddress,
      privateKey: privateKey,
    );
    await SocketService.instance.connect(
      sessionToken: ApiService.instance.sessionToken,
    );
    SocketService.instance.startPing();
    await SyncService.instance.performInitialSync();
    await SyncService.instance.retryPendingMessages();

    _currentWallet = walletAddress;
    _isInitialized = true;
    debugPrint('[AppInitService] Initialized for $walletAddress');
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

  Future<void> dispose() async {
    try {
      await SyncService.instance.dispose();
      SocketService.instance.stopPing();
      await ApiService.instance.dispose();
      await SocketService.instance.disconnect();
      await DbService.instance.closeUserDatabase();
    } finally {
      _isInitialized = false;
      _currentWallet = null;
    }
  }
}
