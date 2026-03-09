import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:web3auth_flutter/input.dart';
import 'package:web3auth_flutter/web3auth_flutter.dart';
import '../../services/auth/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/custom_text_field.dart';
import '../../widgets/auth/primary_button.dart';
import '../home/main_navigation_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;
  bool _isWalletLoading = false;
  bool _isWalletConnecting = false;

  bool get _anyLoading =>
      _isEmailLoading || _isGoogleLoading || _isWalletLoading;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkWalletConnectionOnStart();
  }

  /// Check if wallet is already connected on app start
  Future<void> _checkWalletConnectionOnStart() async {
    try {
      if (AuthService.instance.isAuthenticated) {
        // User is already authenticated, navigate to home
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _navigateToHome();
        });
      }
    } catch (e) {
      // Ignore errors during startup check
      debugPrint('[AuthScreen] Startup wallet check failed: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _emailController.dispose();
    super.dispose();
  }

  /// Handle app lifecycle changes:
  /// - Android: Clear Web3Auth custom tabs when resumed
  /// - All platforms: Check wallet connection when returning from MetaMask
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Platform.isAndroid) {
        Web3AuthFlutter.setCustomTabsClosed();
      }

      // If wallet connection was in progress, check if it completed while app was in background
      if (_isWalletConnecting) {
        _checkWalletConnectionAfterResume();
      }
    }
  }

  /// Check wallet connection status after app resumes from background
  Future<void> _checkWalletConnectionAfterResume() async {
    // Wait a moment for the wallet connection state to update
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted || !_isWalletConnecting) return;

    try {
      // Check if wallet is now connected
      if (AuthService.instance.isAuthenticated) {
        // Connection succeeded while in background
        setState(() {
          _isWalletLoading = false;
          _isWalletConnecting = false;
        });
        _navigateToHome();
      }
    } catch (e) {
      debugPrint('[AuthScreen] Resume wallet check error: $e');
    }
  }

  // ─── Auth handlers ────────────────────────────────────────────────────────

  Future<void> _handleEmailAuth() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isEmailLoading = true);
    try {
      await AuthService.instance.signInWithEmail(_emailController.text.trim());
      if (mounted) _navigateToHome();
    } on UserCancelledException {
      // User closed the browser tab — no error shown
    } catch (e) {
      if (mounted) _showSnack('Authentication failed: $e');
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() => _isGoogleLoading = true);
    try {
      await AuthService.instance.signInWithGoogle();
      if (mounted) _navigateToHome();
    } on UserCancelledException {
      // User closed the auth tab
    } catch (e) {
      if (mounted) _showSnack('Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _handleWalletConnect() async {
    setState(() {
      _isWalletLoading = true;
      _isWalletConnecting = true;
    });

    try {
      // Use Web3Auth's built-in external wallet connection
      await AuthService.instance.signInWithWallet();

      if (mounted) {
        setState(() {
          _isWalletLoading = false;
          _isWalletConnecting = false;
        });
        _navigateToHome();
      }
    } on UserCancelledException {
      // User closed the wallet connection dialog
      if (mounted) {
        setState(() {
          _isWalletLoading = false;
          _isWalletConnecting = false;
        });
      }
    } on UnimplementedError catch (e) {
      if (mounted) {
        setState(() {
          _isWalletLoading = false;
          _isWalletConnecting = false;
        });
        _showSnack(e.message ?? 'Wallet connection not set up yet.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isWalletLoading = false;
          _isWalletConnecting = false;
        });
        _showSnack('Wallet connection failed: $e');
      }
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
    );
  }

  void _showSnack(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.rajdhani(color: AppColors.textPrimary),
        ),
        backgroundColor: success
            ? const Color(0xFF1E3A00)
            : AppColors.surfaceVariant,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Geometric background
          const Positioned.fill(child: _GeometricBackground()),
          // Top accent line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppColors.primaryAccent),
          ),
          // Main content
          SafeArea(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 48),
                    _buildLogoHeader(),
                    const SizedBox(height: 40),

                    // ── Email field ──────────────────────────────────────
                    CustomTextField(
                      label: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v)) {
                          return 'Enter a valid email address';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // ── Passwordless hint ──────────────────────────────────
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'We\'ll send a magic link — no password needed.',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textHint,
                          fontSize: 12,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Continue button ─────────────────────────────────
                    PrimaryButton(
                      text: 'CONTINUE WITH EMAIL',
                      onPressed: _anyLoading ? null : _handleEmailAuth,
                      isLoading: _isEmailLoading,
                    ),
                    const SizedBox(height: 28),

                    // ── OR divider ─────────────────────────────────────
                    _buildOrDivider(),
                    const SizedBox(height: 20),

                    // ── Google button ───────────────────────────────────
                    _AuthProviderButton(
                      icon: FontAwesomeIcons.google,
                      iconColor: AppColors.primaryAccent,
                      label: 'Continue with Google',
                      isLoading: _isGoogleLoading,
                      onPressed: _anyLoading ? null : _handleGoogleAuth,
                      highlightBorder: true,
                    ),
                    const SizedBox(height: 12),

                    // ── Wallet button ───────────────────────────────────
                    _AuthProviderButton(
                      icon: Icons.account_balance_wallet_outlined,
                      isMaterialIcon: true,
                      iconColor: AppColors.primaryAccent,
                      label: 'Connect External Wallet',
                      isLoading: _isWalletLoading,
                      onPressed: _anyLoading ? null : _handleWalletConnect,
                      highlightBorder: true,
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoHeader() {
    return Column(
      children: [
        Image.asset('assets/logo.png', width: 110, height: 110),
        const SizedBox(height: 16),
        Text(
          'MESHLIX',
          style: GoogleFonts.orbitron(
            color: AppColors.primaryAccent,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            letterSpacing: 4.0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Secure. Private. Decentralized.',
          style: GoogleFonts.rajdhani(
            color: AppColors.textSecondary,
            fontSize: 13,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OR',
            style: GoogleFonts.rajdhani(
              color: AppColors.textHint,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 2.0,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.border)),
      ],
    );
  }
}

// ─── Auth Provider Button ────────────────────────────────────────────────────

class _AuthProviderButton extends StatelessWidget {
  final dynamic icon; // IconData (Material) or IconData (FontAwesome)
  final bool isMaterialIcon;
  final Color iconColor;
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;
  final bool highlightBorder;

  const _AuthProviderButton({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.isLoading,
    required this.onPressed,
    this.isMaterialIcon = false,
    this.highlightBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceVariant,
          side: BorderSide(
            color: highlightBorder
                ? AppColors.primaryAccent.withValues(alpha: 0.5)
                : AppColors.border,
            width: highlightBorder ? 1.5 : 1.0,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: AppColors.primaryAccent,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  isMaterialIcon
                      ? Icon(icon as IconData, color: iconColor, size: 18)
                      : FaIcon(icon as IconData, color: iconColor, size: 16),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Geometric Background ────────────────────────────────────────────────────

class _GeometricBackground extends StatelessWidget {
  const _GeometricBackground();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _GeometricPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC8E000).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    const double tileW = 56.0;
    const double tileH = 32.0;

    int rowCount = (size.height / tileH).ceil() + 2;
    int colCount = (size.width / tileW).ceil() + 2;

    for (int row = -1; row < rowCount; row++) {
      for (int col = -1; col < colCount; col++) {
        final double ox = col * tileW + (row % 2 == 0 ? 0 : tileW / 2) - tileW;
        final double oy = row * tileH;

        // Rhombus / diamond tile
        final path = Path()
          ..moveTo(ox + tileW / 2, oy)
          ..lineTo(ox + tileW, oy + tileH / 2)
          ..lineTo(ox + tileW / 2, oy + tileH)
          ..lineTo(ox, oy + tileH / 2)
          ..close();
        canvas.drawPath(path, paint);

        // Vertical centre line — cube depth
        canvas.drawLine(
          Offset(ox + tileW / 2, oy),
          Offset(ox + tileW / 2, oy + tileH / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
