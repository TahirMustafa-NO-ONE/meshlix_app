import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import 'package:web3auth_flutter/enums.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/output.dart';
import 'package:web3dart/web3dart.dart';
import 'auth_user.dart';
import '../wallet/wallet_connect_service.dart';

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
      final response = await Web3AuthFlutter.getWeb3AuthResponse();
      if (response.privKey != null && response.privKey!.isNotEmpty) {
        _currentUser = _toUser(response, AuthProvider.unknown);
      }
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
  /// Uses Reown AppKit (WalletConnect v2) to establish connection with the wallet app.
  /// [walletId] optional specific wallet to connect to (e.g., 'metamask', 'walletconnect')
  /// Returns an [AuthUser] with the connected wallet address.
  Future<AuthUser> signInWithWallet(
    dynamic context, {
    String? walletId,
  }) async {
    try {
      // Check if already connected
      if (WalletConnectService.instance.isConnected) {
        // Already connected, use existing address
        final address = WalletConnectService.instance.connectedAddress!;
        final username =
            'user_${address.substring(2, 6)}${address.substring(address.length - 4)}';
        _currentUser = AuthUser(
          publicAddress: address,
          username: username,
          name: 'External Wallet',
          provider: AuthProvider.externalWallet,
        );
        debugPrint(
          '[AuthService] Using existing wallet connection: $address',
        );
        return _currentUser!;
      }

      // Connect to the wallet (pass walletId to avoid showing modal for specific wallets)
      final address = await WalletConnectService.instance.connectWallet(
        context,
        walletId: walletId,
      );

      // Create a challenge message for the user to sign
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final challengeMessage =
          'Sign this message to authenticate with Meshlix.\n\n'
          'Timestamp: $timestamp\n'
          'Wallet: $address';

      // Request signature to prove ownership
      // This is optional - if user rejects, we still create the account
      String? signature;
      try {
        signature = await WalletConnectService.instance.signMessage(
          challengeMessage,
        );
        debugPrint('[AuthService] Message signed successfully');
      } catch (signError) {
        // User might have rejected the signature request
        // We still proceed with wallet connection but log the error
        debugPrint('[AuthService] Signature request failed: $signError');
        // Continue without signature - wallet connection is still valid
      }

      // Create and return an AuthUser with the connected wallet address
      final username =
          'user_${address.substring(2, 6)}${address.substring(address.length - 4)}';
      _currentUser = AuthUser(
        publicAddress: address,
        username: username,
        name: 'External Wallet',
        provider: AuthProvider.externalWallet,
      );

      return _currentUser!;
    } on Object catch (e) {
      debugPrint('[AuthService] External wallet sign-in failed: $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    try {
      // Check which provider the user used to sign in
      if (_currentUser?.provider == AuthProvider.externalWallet) {
        // User signed in with external wallet (MetaMask, Trust Wallet, etc.)
        // Disconnect from WalletConnect
        await WalletConnectService.instance.disconnect();
        debugPrint('[AuthService] External wallet disconnected');
      } else {
        // User signed in with Web3Auth (email, Google, or Web3Auth wallet)
        // Only call Web3AuthFlutter.logout() if there's an active Web3Auth session
        try {
          await Web3AuthFlutter.logout();
          debugPrint('[AuthService] Web3Auth session logged out');
        } catch (e) {
          // If logout fails (e.g., no active session), log and continue
          debugPrint('[AuthService] Web3Auth logout failed: $e');
          // Still proceed to clear current user
        }
      }
    } catch (e) {
      // Log any errors but don't throw - we still want to clear the user state
      debugPrint('[AuthService] Sign out error: $e');
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
