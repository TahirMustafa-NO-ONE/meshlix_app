import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3dart/web3dart.dart';
import 'auth_user.dart';
import '../storage/user_storage.dart';
import '../session/session_manager.dart';

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
  /// Three-phase init:
  ///  1. Check for persisted session in SessionManager/UserStorage
  ///  2. [Web3AuthFlutter.init] — registers the SDK with the native layer.
  ///  3. [Web3AuthFlutter.initialize] — only called if no local session exists
  Future<void> initialize() async {
    // ── Phase 1: Check for persisted local session ─────────────────────────
    // This is critical for maintaining login across app restarts
    bool hasLocalSession = false;

    try {
      hasLocalSession = await SessionManager.instance.isLoggedIn();

      if (hasLocalSession) {
        debugPrint('[AuthService] Found local session, attempting to restore...');

        // Get stored session data
        final session = await SessionManager.instance.getSession();
        final userAddress = session?['userAddress'] as String?;

        if (userAddress != null) {
          // Load user details from UserStorage
          final users = await UserStorage.instance.getAllUsers();
          final userIndex = users.indexWhere(
            (u) => u.publicAddress == userAddress,
          );

          if (userIndex != -1) {
            // Restore the user session without calling Web3Auth
            _currentUser = users[userIndex];

            debugPrint(
              '[AuthService] Local session restored for: ${_currentUser!.email ?? _currentUser!.publicAddress}',
            );
            debugPrint(
              '[AuthService] Skipping Web3Auth.initialize() - using local session',
            );
          } else {
            debugPrint(
              '[AuthService] User not found in storage, session will be cleared by splash screen',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('[AuthService] Error restoring local session: $e');
      // Continue initialization - session will be cleared by splash screen if invalid
      _currentUser = null;
      hasLocalSession = false;
    }

    // ── Phase 2: SDK registration ──────────────────────────────────────────
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
      debugPrint('[AuthService] Web3Auth SDK initialized');
      debugPrint('[AuthService] Client ID: ${_clientId.substring(0, 20)}...');
      debugPrint('[AuthService] Network: $_network');
      debugPrint('[AuthService] Redirect: $_redirectScheme://auth');
    } on Object catch (e) {
      // SDK registration failed (invalid clientId, missing plugin, etc.).
      // Auth methods will throw a descriptive error when called.
      debugPrint('[AuthService] Web3AuthFlutter.init failed: $e');
      return;
    }

    // ── Phase 3: Web3Auth session restoration (only if no local session) ───
    // Only attempt Web3Auth session restoration if we don't already have a local session
    if (!hasLocalSession) {
      try {
        await Web3AuthFlutter.initialize();
        final response = await Web3AuthFlutter.getWeb3AuthResponse();
        if (response.privKey != null && response.privKey!.isNotEmpty) {
          _currentUser = _toUser(response, AuthProvider.unknown);

          // Save user to storage
          await UserStorage.instance.saveUser(_currentUser!);

          // Save session for persistent login
          await SessionManager.instance.saveSession(
            authToken: response.privKey ?? '',
            userId: _currentUser!.email ?? _currentUser!.publicAddress,
            userAddress: _currentUser!.publicAddress,
          );

          debugPrint('[AuthService] Web3Auth session restored');
        }
      } on Object catch (_) {
        // No prior Web3Auth session — user must sign in.
        debugPrint('[AuthService] No Web3Auth session found');
      }
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

    // Save user to storage
    await UserStorage.instance.saveUser(_currentUser!);

    // Save session for persistent login
    await SessionManager.instance.saveSession(
      authToken: response.privKey ?? '',
      userId: _currentUser!.email ?? _currentUser!.publicAddress,
      userAddress: _currentUser!.publicAddress,
    );

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

    // Save user to storage
    await UserStorage.instance.saveUser(_currentUser!);

    // Save session for persistent login
    await SessionManager.instance.saveSession(
      authToken: response.privKey ?? '',
      userId: _currentUser!.email ?? _currentUser!.publicAddress,
      userAddress: _currentUser!.publicAddress,
    );

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
    debugPrint('[AuthService] External wallet sign-in coming soon');
    throw Exception(
      'External wallet connection is coming soon.\n'
      'Please use Google Sign-In or Email OTP for now.',
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

      // Clear session data for persistent login
      await SessionManager.instance.clearSession();
      debugPrint('[AuthService] Session cleared');
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
