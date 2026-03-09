import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3dart/web3dart.dart';
import 'auth_user.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  AuthUser? _currentUser;
  AuthUser? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  // ─────────────────────────────────────────────────────────────────────────
  // CONFIGURATION
  // Set these values in the .env file:
  //   • WEB3AUTH_CLIENT_ID → from https://dashboard.web3auth.io
  //   • WEB3AUTH_NETWORK   → sapphire_devnet (dev) or sapphire_mainnet (prod)
  //   • redirectUrl scheme → must match AndroidManifest.xml + Info.plist
  // ─────────────────────────────────────────────────────────────────────────
  static String get _clientId =>
      dotenv.env['WEB3AUTH_CLIENT_ID'] ?? 'YOUR_WEB3AUTH_CLIENT_ID';

  static Network get _network {
    final networkStr = dotenv.env['WEB3AUTH_NETWORK'] ?? 'sapphire_devnet';
    return networkStr == 'sapphire_mainnet'
        ? Network.sapphire_mainnet
        : Network.sapphire_devnet;
  }

  static const String _redirectScheme = 'meshlix'; // custom deep-link scheme

  // ─────────────────────────────────────────────────────────────────────────
  // INIT
  // ─────────────────────────────────────────────────────────────────────────

  /// Call once after [runApp] — use [MeshlixApp]'s addPostFrameCallback.
  ///
  /// Two-phase init:
  ///  1. [Web3AuthFlutter.init] — registers the SDK with the native layer.
  ///     If this fails (e.g. placeholder clientId, missing native plugin),
  ///     the rest of the app still runs normally; auth buttons will surface
  ///     the error inline.
  ///  2. [Web3AuthFlutter.initialize] — tries to restore a prior session.
  ///     Expected to throw on first launch; caught and ignored.
  Future<void> initialize() async {
    // ── Phase 1: SDK registration ──────────────────────────────────────────
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
      debugPrint('[AuthService] Web3Auth initialized successfully');
      debugPrint('[AuthService] Client ID: ${_clientId.substring(0, 20)}...');
      debugPrint('[AuthService] Network: $_network');
      debugPrint('[AuthService] Redirect: $_redirectScheme://auth');
    } on Object catch (e) {
      // SDK registration failed (invalid clientId, missing plugin, etc.).
      // Auth methods will throw a descriptive error when called.
      debugPrint('[AuthService] Web3AuthFlutter.init failed: $e');
      return;
    }

    // ── Phase 2: Session restoration (optional) ────────────────────────────
    try {
      await Web3AuthFlutter.initialize();
      final response = await Web3AuthFlutter.getWeb3AuthResponse();
      if (response.privKey != null && response.privKey!.isNotEmpty) {
        _currentUser = _toUser(response, AuthProvider.unknown);
        debugPrint('[AuthService] Session restored for user');
      }
    } on Object catch (_) {
      // No prior session — user must sign in.
      debugPrint('[AuthService] No existing session found');
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // GOOGLE SIGN-IN
  // ─────────────────────────────────────────────────────────────────────────

  /// Opens the Google OAuth screen inside a Chrome Custom Tab (Android) or
  /// SFSafariViewController (iOS). Resolves once the user completes the flow.
  Future<AuthUser> signInWithGoogle() async {
    final response = await Web3AuthFlutter.login(
      LoginParams(loginProvider: Provider.google),
    );
    _currentUser = _toUser(response, AuthProvider.google);
    return _currentUser!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EMAIL PASSWORDLESS (magic link / OTP)
  // ─────────────────────────────────────────────────────────────────────────

  /// Sends a magic-link / OTP to [email].
  ///
  /// Web3Auth opens a browser tab where the user clicks the link or enters
  /// the one-time code. The returned [Future] resolves once authentication
  /// is complete (tab is closed and control returns to the app).
  Future<AuthUser> signInWithEmail(String email) async {
    final response = await Web3AuthFlutter.login(
      LoginParams(
        loginProvider: Provider.email_passwordless,
        extraLoginOptions: ExtraLoginOptions(login_hint: email),
      ),
    );
    _currentUser = _toUser(response, AuthProvider.emailOTP);
    return _currentUser!;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // EXTERNAL WALLET
  // ─────────────────────────────────────────────────────────────────────────

  /// Connect an external Web3 wallet (MetaMask, etc.) using Web3Auth
  ///
  /// Web3Auth doesn't support direct external wallet login via Provider enum.
  /// External wallets require using Web3Auth's Wallet Services or Custom Authentication.
  /// For now, this returns an error - implement using Web3Auth Wallet Services SDK.
  Future<AuthUser> signInWithWallet() async {
    throw UnimplementedError(
      'External wallet connection via Web3Auth requires additional setup.\n'
      'Options:\n'
      '1. Use Web3Auth Wallet Services (separate SDK)\n'
      '2. Configure custom JWT verifier in Web3Auth dashboard\n'
      '3. Use direct WalletConnect integration (requires separate package)',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      // For all authentication methods (including external wallet),
      // use Web3AuthFlutter.logout()
      await Web3AuthFlutter.logout();
      debugPrint('[AuthService] Logged out successfully');
    } catch (e) {
      // If logout fails (e.g., no active session), log and continue
      debugPrint('[AuthService] Logout failed: $e');
      // Still proceed to clear current user
    } finally {
      // Always clear the current user, regardless of errors
      _currentUser = null;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  /// Derives Ethereum public address from secp256k1 private key
  String _deriveAddress(String privateKeyHex) {
    // Remove '0x' prefix if present
    final cleaned = privateKeyHex.startsWith('0x')
        ? privateKeyHex.substring(2)
        : privateKeyHex;

    final credentials = EthPrivateKey.fromHex(cleaned);
    final address = credentials.address;
    return address.hexEip55;
  }

  AuthUser _toUser(Web3AuthResponse r, AuthProvider provider) {
    if (r.privKey == null || r.privKey!.isEmpty) {
      throw Exception('No private key received from Web3Auth');
    }

    final publicAddress = _deriveAddress(r.privKey!);

    return AuthUser.fromWeb3AuthResponse(
      address: publicAddress,
      userInfo: r.userInfo,
      provider: provider,
    );
  }
}
