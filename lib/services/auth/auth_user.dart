import 'package:web3auth_flutter/output.dart';

enum AuthProvider { google, emailOTP, wallet, unknown }

/// Normalized user model populated after any successful Web3Auth sign-in.
class AuthUser {
  final String? email;
  final String? name;
  final String? profileImage;

  /// secp256k1 private key — use to derive the user's EVM address.
  /// Store this only in secure storage; never log it.
  final String? privKey;

  final AuthProvider provider;

  const AuthUser({
    this.email,
    this.name,
    this.profileImage,
    this.privKey,
    required this.provider,
  });

  factory AuthUser.fromTorusInfo(TorusUserInfo info, AuthProvider provider) {
    return AuthUser(
      email: info.email,
      name: info.name,
      profileImage: info.profileImage,
      provider: provider,
    );
  }

  String get displayName => name ?? email ?? 'Meshlix User';

  @override
  String toString() =>
      'AuthUser(provider: $provider, email: $email, name: $name)';
}
