import 'package:flutter/foundation.dart';
import '../db/db_service.dart';
import 'xmtp/xmtp_service.dart';
import 'sync/sync_service.dart';
import 'session/session_manager.dart';

/// App Initialization Service
///
/// Handles initializing all services after successful authentication.
/// This is called after login to set up:
/// - User-scoped database (Hive)
/// - XMTP client
/// - Initial sync from XMTP to local DB
/// - Real-time message streaming
class AppInitService {
  AppInitService._();
  static final AppInitService instance = AppInitService._();

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  String? _currentWallet;

  /// Initialize all services for the authenticated user
  ///
  /// [walletAddress] - The user's Ethereum wallet address
  /// Call this after successful login or session restoration
  Future<void> initializeForUser(String walletAddress) async {
    if (_isInitialized && _currentWallet == walletAddress) {
      debugPrint(
        '[AppInitService] Already initialized for wallet: $walletAddress',
      );
      return;
    }

    debugPrint(
      '[AppInitService] Initializing services for wallet: $walletAddress',
    );

    try {
      // 1. Open user-scoped database
      debugPrint('[AppInitService] Opening user database...');
      await DbService.instance.openUserDatabase(walletAddress);

      // 2. Initialize XMTP client
      debugPrint('[AppInitService] Initializing XMTP client...');
      await XmtpService.instance.initialize(walletAddress: walletAddress);

      // 3. Perform initial sync from XMTP to local DB
      debugPrint('[AppInitService] Performing initial sync...');
      await SyncService.instance.performInitialSync();

      // 4. Retry any pending messages from offline queue
      debugPrint('[AppInitService] Retrying pending messages...');
      await SyncService.instance.retryPendingMessages();

      _currentWallet = walletAddress;
      _isInitialized = true;

      debugPrint('[AppInitService] All services initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('[AppInitService] Failed to initialize services: $e');
      debugPrint('[AppInitService] Stack trace: $stackTrace');
      // Don't rethrow - allow app to continue even if XMTP fails
      // User can still see cached data
    }
  }

  /// Initialize from stored session
  ///
  /// Call this on app startup when a valid session exists
  Future<bool> initializeFromSession() async {
    try {
      final walletAddress = await SessionManager.instance.getUserAddress();
      if (walletAddress == null) {
        debugPrint('[AppInitService] No wallet address in session');
        return false;
      }

      await initializeForUser(walletAddress);
      return true;
    } catch (e) {
      debugPrint('[AppInitService] Failed to initialize from session: $e');
      return false;
    }
  }

  /// Clean up services on logout
  ///
  /// Call this when user logs out to properly close connections
  Future<void> dispose() async {
    debugPrint('[AppInitService] Disposing services...');

    try {
      // Stop real-time sync
      await SyncService.instance.dispose();

      // Close database
      await DbService.instance.closeUserDatabase();

      // Close XMTP
      await XmtpService.instance.dispose();

      _isInitialized = false;
      _currentWallet = null;

      debugPrint('[AppInitService] Services disposed');
    } catch (e) {
      debugPrint('[AppInitService] Error disposing services: $e');
    }
  }
}
