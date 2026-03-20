import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class PrivateKeyStorage {
  PrivateKeyStorage._();
  static final PrivateKeyStorage instance = PrivateKeyStorage._();

  static const _keyPrefix = 'wallet_private_key_';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  Future<void> savePrivateKey({
    required String walletAddress,
    required String privateKey,
  }) async {
    await _storage.write(
      key: _getKey(walletAddress),
      value: privateKey,
    );
    debugPrint('[PrivateKeyStorage] Saved private key for $walletAddress');
  }

  Future<String?> loadPrivateKey(String walletAddress) async {
    return _storage.read(key: _getKey(walletAddress));
  }

  Future<void> deletePrivateKey(String walletAddress) async {
    await _storage.delete(key: _getKey(walletAddress));
  }

  String _getKey(String walletAddress) {
    return '$_keyPrefix${walletAddress.toLowerCase()}';
  }
}
