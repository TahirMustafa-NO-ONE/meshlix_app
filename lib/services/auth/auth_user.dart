import 'package:web3auth_flutter/output.dart';

enum AuthProvider { google, emailOTP, wallet, externalWallet, unknown }

/// Normalized user model populated after any successful Web3Auth sign-in.
class AuthUser {
  final String? email;
  final String? name;
  final String? profileImage;

  /// Ethereum public address (0x...)
  final String publicAddress;

  /// Random username for display (generated from address)
  final String username;

  final AuthProvider provider;

  const AuthUser({
    this.email,
    this.name,
    this.profileImage,
    required this.publicAddress,
    required this.username,
    required this.provider,
  });

  factory AuthUser.fromWeb3AuthResponse({
    required String address,
    TorusUserInfo? userInfo,
    required AuthProvider provider,
  }) {
    // Generate random username from address (first 4 chars + last 4 chars)
    final username =
        'user_${address.substring(2, 6)}${address.substring(address.length - 4)}';

    return AuthUser(
      email: userInfo?.email,
      name: userInfo?.name,
      profileImage: userInfo?.profileImage,
      publicAddress: address,
      username: username,
      provider: provider,
    );
  }

  String get displayName => name ?? username;

  String get shortAddress =>
      '${publicAddress.substring(0, 6)}...${publicAddress.substring(publicAddress.length - 4)}';

  @override
  String toString() =>
      'AuthUser(provider: $provider, address: $publicAddress, email: $email, name: $name)';
}
