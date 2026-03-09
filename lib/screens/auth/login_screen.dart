import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/custom_text_field.dart';
import '../../widgets/auth/primary_button.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      // TODO: implement authentication
      await Future.delayed(const Duration(seconds: 1));
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const Positioned.fill(child: _GeometricBackground()),
          // Top accent line
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppColors.primaryAccent),
          ),
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
                    CustomTextField(
                      label: 'Email Address',
                      prefixIcon: Icons.email_outlined,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
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
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      controller: _passwordController,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {},
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'Forgot Password?',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.primaryAccent,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      text: 'LOG IN',
                      onPressed: _isLoading ? null : _handleLogin,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 28),
                    _buildOrDivider(),
                    const SizedBox(height: 20),
                    _buildSocialButtons(),
                    const SizedBox(height: 36),
                    _buildSignUpLink(context),
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
          'Connect. Build. Deliver.',
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

  Widget _buildSocialButtons() {
    return Row(
      children: [
        Expanded(
          child: _SocialButton(
            icon: FontAwesomeIcons.google,
            label: 'Google',
            onPressed: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SocialButton(
            icon: FontAwesomeIcons.apple,
            label: 'Apple',
            onPressed: () {},
          ),
        ),
      ],
    );
  }

  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.rajdhani(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SignupScreen()),
          ),
          child: Text(
            'Sign Up',
            style: GoogleFonts.rajdhani(
              color: AppColors.primaryAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Social Button ──────────────────────────────────────────────────────────

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icon, size: 15, color: AppColors.textPrimary),
      label: Text(
        label,
        style: GoogleFonts.rajdhani(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: OutlinedButton.styleFrom(
        backgroundColor: AppColors.surfaceVariant,
        side: const BorderSide(color: AppColors.border, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

// ─── Geometric Background ───────────────────────────────────────────────────

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

        // Vertical centre line — gives cube depth illusion
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
