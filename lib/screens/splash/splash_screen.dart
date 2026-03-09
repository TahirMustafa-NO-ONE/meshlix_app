import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth/auth_service.dart';
import '../../services/session/session_manager.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../home/home_screen.dart';

/// Splash screen that checks for existing session and routes accordingly
///
/// Flow:
/// 1. Show splash screen with logo and loading indicator
/// 2. Check if SessionManager has a valid stored session
/// 3. Check if AuthService successfully restored user from local storage
/// 4. Route to HomeScreen if authenticated, AuthScreen otherwise
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  /// Check if a valid session exists and navigate to appropriate screen
  Future<void> _checkSessionAndNavigate() async {
    // Add a minimum delay to show splash screen (better UX)
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    try {
      // Check if user has a valid session
      // Note: SessionManager.initialize() was already called in main.dart
      final isLoggedIn = await SessionManager.instance.isLoggedIn();

      if (isLoggedIn) {
        // Check if AuthService successfully restored the user
        // This should be true if AuthService.initialize() successfully loaded from local storage
        if (AuthService.instance.isAuthenticated) {
          debugPrint(
            '[SplashScreen] Valid session found, user authenticated, navigating to home',
          );
          if (mounted) _navigateToHome();
        } else {
          // Session exists in storage but AuthService didn't restore properly
          // This could happen if user data is corrupted or missing
          debugPrint(
            '[SplashScreen] Session exists but user not authenticated, clearing session',
          );
          await SessionManager.instance.clearSession();
          if (mounted) _navigateToAuth();
        }
      } else {
        debugPrint('[SplashScreen] No valid session found, navigating to auth');
        if (mounted) _navigateToAuth();
      }
    } catch (e) {
      debugPrint('[SplashScreen] Error checking session: $e');
      // On any error, clear potentially corrupted session and go to login
      await SessionManager.instance.clearSession();
      if (mounted) _navigateToAuth();
    }
  }

  void _navigateToHome() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  void _navigateToAuth() {
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const AuthScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Top accent line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppColors.primaryAccent),
          ),
          // Centered logo and loading indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Image.asset('assets/logo.png', width: 140, height: 140),
                const SizedBox(height: 24),
                // App name
                Text(
                  'MESHLIX',
                  style: GoogleFonts.orbitron(
                    color: AppColors.primaryAccent,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6.0,
                  ),
                ),
                const SizedBox(height: 8),
                // Tagline
                Text(
                  'Connect. Build. Deliver.',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 48),
                // Loading indicator
                SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    color: AppColors.primaryAccent,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                // Loading text
                Text(
                  'Checking session...',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textHint,
                    fontSize: 13,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
