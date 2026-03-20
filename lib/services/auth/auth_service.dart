import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3dart/web3dart.dart';
import '../session/session_manager.dart';
import '../storage/private_key_storage.dart';
import '../storage/user_storage.dart';
import 'auth_user.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  static String get _clientId =>
      dotenv.env['WEB3AUTH_CLIENT_ID'] ?? 'YOUR_WEB3AUTH_CLIENT_ID';

  static Network get _network {
    final networkStr = dotenv.env['WEB3AUTH_NETWORK'] ?? 'sapphire_devnet';
    return networkStr == 'sapphire_mainnet'
        ? Network.sapphire_mainnet
        : Network.sapphire_devnet;
  }

  static const String _redirectScheme = 'meshlix';

  Future<void> initialize() async {
    bool hasLocalSession = false;

    try {
      hasLocalSession = await SessionManager.instance.isLoggedIn();
      if (hasLocalSession) {
        final session = await SessionManager.instance.getSession();
        final userAddress = session?['userAddress'] as String?;

        if (userAddress != null) {
          final users = await UserStorage.instance.getAllUsers();
          final userIndex = users.indexWhere(
            (u) => u.publicAddress == userAddress,
          );
          if (userIndex != -1) {
            _currentUser = users[userIndex];
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Error restoring local session: $e');
      _currentUser = null;
      hasLocalSession = false;
    }

    try {
      await Web3AuthFlutter.init(
        Web3AuthOptions(
          clientId: _clientId,
          network: _network,
          buildEnv: BuildEnv.production,
          redirectUrl: Uri.parse('$_redirectScheme://auth'),
          whiteLabel: WhiteLabelData(
            appName: 'Meshlix',
            mode: ThemeModes.dark,
            defaultLanguage: Language.en,
          ),
        ),
      );
    } on Object catch (e) {
      debugPrint('[AuthService] Web3AuthFlutter.init failed: $e');
      return;
    }

    if (!hasLocalSession) {
      try {
        await Web3AuthFlutter.initialize();
        final response = await Web3AuthFlutter.getWeb3AuthResponse();
        if (response.privKey != null && response.privKey!.isNotEmpty) {
          await _hydrateAuthenticatedUser(response, AuthProvider.unknown);
        }
      } on Object catch (_) {
        debugPrint('[AuthService] No Web3Auth session found');
      }
    }
  }

  Future<AuthUser> signInWithGoogle() async {
    final response = await Web3AuthFlutter.login(
      LoginParams(loginProvider: Provider.google),
    );
    return _hydrateAuthenticatedUser(response, AuthProvider.google);
  }

  Future<AuthUser> signInWithEmail(String email) async {
    final response = await Web3AuthFlutter.login(
      LoginParams(
        loginProvider: Provider.email_passwordless,
        extraLoginOptions: ExtraLoginOptions(login_hint: email),
      ),
    );
    return _hydrateAuthenticatedUser(response, AuthProvider.emailOTP);
  }

  Future<AuthUser> signInWithWallet() async {
    throw Exception(
      'External wallet connection is coming soon.\n'
      'Please use Google Sign-In or Email OTP for now.',
    );
  }

  Future<void> signOut() async {
    final walletAddress = _currentUser?.publicAddress;

    try {
      await Web3AuthFlutter.logout();
    } catch (e) {
      debugPrint('[AuthService] Logout failed: $e');
    } finally {
      if (walletAddress != null) {
        await PrivateKeyStorage.instance.deletePrivateKey(walletAddress);
      }
      _currentUser = null;
      await SessionManager.instance.clearSession();
    }
  }

  Future<AuthUser> _hydrateAuthenticatedUser(
    Web3AuthResponse response,
    AuthProvider provider,
  ) async {
    final user = _toUser(response, provider);
    final privateKey = response.privKey;

    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('No private key received from Web3Auth');
    }

    _currentUser = user;
    await UserStorage.instance.saveUser(user);
    await PrivateKeyStorage.instance.savePrivateKey(
      walletAddress: user.publicAddress,
      privateKey: privateKey,
    );
    await SessionManager.instance.saveSession(
      userId: user.email ?? user.publicAddress,
      userAddress: user.publicAddress,
    );

    return user;
  }

  String _deriveAddress(String privateKeyHex) {
    final cleaned = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;

    final credentials = EthPrivateKey.fromHex(cleaned);
    return credentials.address.hexEip55;
  }

  AuthUser _toUser(Web3AuthResponse response, AuthProvider provider) {
    if (response.privKey == null || response.privKey!.isEmpty) {
      throw Exception('No private key received from Web3Auth');
    }

    final publicAddress = _deriveAddress(response.privKey!);
    return AuthUser.fromWeb3AuthResponse(
      address: publicAddress,
      userInfo: response.userInfo,
      provider: provider,
    );
  }
}
