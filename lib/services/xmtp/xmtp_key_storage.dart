import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service to securely store and retrieve XMTP keys per user
///
/// CRITICAL: Keys must be stored per wallet address to support multi-user
/// Each user has their own XMTP identity that must be preserved across sessions
class XmtpKeyStorage {
  XmtpKeyStorage._();
  static final XmtpKeyStorage instance = XmtpKeyStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  /// Generate storage key for a specific wallet address
  String _getKeyForWallet(String walletAddress) {
    return 'xmtp_keys_${walletAddress.toLowerCase()}';
  }

  /// Save XMTP keys for a specific wallet address
  ///
  /// [walletAddress] - The wallet address (0x...)
  /// [keysData] - Base64 encoded XMTP keys from client.keys.writeToBuffer()
  Future<void> saveKeys({
    required String walletAddress,
    required String keysData,
  }) async {
    try {
      final key = _getKeyForWallet(walletAddress);
      await _storage.write(key: key, value: keysData);
      debugPrint('[XmtpKeyStorage] Keys saved for wallet: $walletAddress');
    } catch (e) {
      debugPrint('[XmtpKeyStorage] Failed to save keys: $e');
      rethrow;
    }
  }

  /// Load XMTP keys for a specific wallet address
  ///
  /// Returns null if no keys are stored for this wallet
  Future<String?> loadKeys(String walletAddress) async {
    try {
      final key = _getKeyForWallet(walletAddress);
      final keysData = await _storage.read(key: key);

      if (keysData != null) {
        debugPrint('[XmtpKeyStorage] Keys loaded for wallet: $walletAddress');
      } else {
        debugPrint(
          '[XmtpKeyStorage] No stored keys found for wallet: $walletAddress',
        );
      }

      return keysData;
    } catch (e) {
      debugPrint('[XmtpKeyStorage] Failed to load keys: $e');
      return null;
    }
  }

  /// Check if keys exist for a wallet address
  Future<bool> hasKeys(String walletAddress) async {
    final keys = await loadKeys(walletAddress);
    return keys != null;
  }

  /// Delete keys for a specific wallet address
  ///
  /// Use this when logging out permanently or clearing user data
  Future<void> deleteKeys(String walletAddress) async {
    try {
      final key = _getKeyForWallet(walletAddress);
      await _storage.delete(key: key);
      debugPrint('[XmtpKeyStorage] Keys deleted for wallet: $walletAddress');
    } catch (e) {
      debugPrint('[XmtpKeyStorage] Failed to delete keys: $e');
      rethrow;
    }
  }

  /// Clear all stored XMTP keys (for all users)
  ///
  /// WARNING: This will delete XMTP identities for all users
  Future<void> clearAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('[XmtpKeyStorage] All keys cleared');
    } catch (e) {
      debugPrint('[XmtpKeyStorage] Failed to clear all keys: $e');
      rethrow;
    }
  }
}
