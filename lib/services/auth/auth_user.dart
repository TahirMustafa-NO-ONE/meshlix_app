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

  // Additional Web3Auth metadata
  final String? verifier;
  final String? verifierId;
  final String? typeOfLogin;
  final String? aggregateVerifier;

  const AuthUser({
    this.email,
    this.name,
    this.profileImage,
    required this.publicAddress,
    required this.username,
    required this.provider,
    this.verifier,
    this.verifierId,
    this.typeOfLogin,
    this.aggregateVerifier,
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
      verifier: userInfo?.verifier,
      verifierId: userInfo?.verifierId,
      typeOfLogin: userInfo?.typeOfLogin,
      aggregateVerifier: userInfo?.aggregateVerifier,
    );
  }

  String get displayName => name ?? username;

  String get shortAddress =>
      '${publicAddress.substring(0, 6)}...${publicAddress.substring(publicAddress.length - 4)}';

  String get providerDisplayName {
    switch (provider) {
      case AuthProvider.google:
        return 'Google';
      case AuthProvider.emailOTP:
        return 'Email (OTP)';
      case AuthProvider.wallet:
        return 'Web3Auth Wallet';
      case AuthProvider.externalWallet:
        return 'External Wallet';
      case AuthProvider.unknown:
        return 'Unknown';
    }
  }

  @override
  String toString() =>
      'AuthUser(provider: $provider, address: $publicAddress, email: $email, name: $name)';
}
