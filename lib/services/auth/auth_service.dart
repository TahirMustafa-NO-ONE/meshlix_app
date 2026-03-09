import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
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
          redirectUrl: Uri.parse('$_redirectScheme://auth'),
          whiteLabel: WhiteLabelData(
            appName: 'Meshlix',
            mode: ThemeModes.dark,
            defaultLanguage: Language.en,
          ),
        ),
      );
    } on Object catch (e) {
      // SDK registration failed (invalid clientId, missing plugin, etc.).
      // Auth methods will throw a descriptive error when called.
      debugPrint('[AuthService] Web3AuthFlutter.init failed: $e');
      return;
    }

    // ── Phase 2: Session restoration (optional) ────────────────────────────
    try {
      await Web3AuthFlutter.initialize();
      final info = await Web3AuthFlutter.getUserInfo();
      _currentUser = AuthUser.fromTorusInfo(info, AuthProvider.unknown);
    } on Object catch (_) {
      // No prior session — user must sign in.
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

  /// Connect an external Web3 wallet (MetaMask, Trust Wallet, Rainbow, etc.)
  ///
  /// Web3Auth v6 does not include native external-wallet support directly.
  /// The recommended production integration path is:
  ///
  ///   1. Add `walletconnect_flutter_v2` to pubspec.yaml.
  ///   2. Obtain a Project ID at https://cloud.walletconnect.com.
  ///   3. Create a WalletConnectFlutterV2 instance, generate a pairing URI,
  ///      and deep-link / QR the URI into the chosen wallet app.
  ///   4. On `SessionApproveEvent`, obtain the connected address + sign a
  ///      challenge message to prove ownership.
  ///   5. Pass the signed JWT to Web3Auth Custom Auth to mint a Web3Auth
  ///      session for that address.
  ///
  /// This stub throws [UnimplementedError] until the above steps are wired up.
  /// The UI (WalletConnectSheet) is fully built and ready to hook in.
  Future<AuthUser> signInWithWallet(String walletId) async {
    throw UnimplementedError(
      'External wallet sign-in is not yet wired up. '
      'See the TODO inside AuthService.signInWithWallet().',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await Web3AuthFlutter.logout();
    _currentUser = null;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  AuthUser _toUser(Web3AuthResponse r, AuthProvider provider) {
    return AuthUser(
      email: r.userInfo?.email,
      name: r.userInfo?.name,
      profileImage: r.userInfo?.profileImage,
      privKey: r.privKey,
      provider: provider,
    );
  }
}
