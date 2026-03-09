import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../theme/app_colors.dart';
import '../../widgets/auth/custom_text_field.dart';
import '../../widgets/auth/primary_button.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _agreeToTerms = false;
  double _passwordStrength = 0;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(() {
      setState(() {
        _passwordStrength = _calculateStrength(_passwordController.text);
      });
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  double _calculateStrength(String password) {
    if (password.isEmpty) return 0;
    double strength = 0;
    if (password.length >= 8) strength += 0.25;
    if (password.length >= 12) strength += 0.1;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[0-9]').hasMatch(password)) strength += 0.2;
    if (RegExp(r'[!@#\$&*~%^()_\-+=<>?]').hasMatch(password)) strength += 0.25;
    return strength.clamp(0.0, 1.0);
  }

  Color _strengthColor(double strength) {
    if (strength < 0.35) return AppColors.error;
    if (strength < 0.65) return const Color(0xFFFFAA00);
    return AppColors.primaryAccent;
  }

  String _strengthLabel(double strength) {
    if (strength < 0.35) return 'Weak';
    if (strength < 0.65) return 'Fair';
    if (strength < 0.85) return 'Good';
    return 'Strong';
  }

  Future<void> _handleSignup() async {
    if (!_agreeToTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please accept the Terms & Conditions to continue.',
            style: GoogleFonts.rajdhani(),
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      // TODO: implement registration
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
                    const SizedBox(height: 40),
                    _buildLogoHeader(),
                    const SizedBox(height: 32),
                    // ── Form fields ──────────────────────────────────────
                    CustomTextField(
                      label: 'Full Name',
                      prefixIcon: Icons.person_outline,
                      controller: _nameController,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Full name is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
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
                      label: 'Phone Number (optional)',
                      prefixIcon: Icons.phone_outlined,
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      controller: _passwordController,
                      textInputAction: TextInputAction.next,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 10),
                    // ── Password strength indicator ──────────────────────
                    _buildPasswordStrength(),
                    const SizedBox(height: 16),
                    CustomTextField(
                      label: 'Confirm Password',
                      prefixIcon: Icons.lock_outline,
                      isPassword: true,
                      controller: _confirmPasswordController,
                      textInputAction: TextInputAction.done,
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Please confirm your password';
                        }
                        if (v != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    // ── Terms checkbox ───────────────────────────────────
                    _buildTermsRow(),
                    const SizedBox(height: 28),
                    PrimaryButton(
                      text: 'CREATE ACCOUNT',
                      onPressed: _isLoading ? null : _handleSignup,
                      isLoading: _isLoading,
                    ),
                    const SizedBox(height: 28),
                    _buildOrDivider(),
                    const SizedBox(height: 20),
                    _buildSocialButtons(),
                    const SizedBox(height: 36),
                    _buildLoginLink(context),
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
        Image.asset('assets/logo.png', width: 100, height: 100),
        const SizedBox(height: 14),
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

  Widget _buildPasswordStrength() {
    if (_passwordController.text.isEmpty) return const SizedBox.shrink();
    final strength = _passwordStrength;
    final color = _strengthColor(strength);
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: strength,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            _strengthLabel(strength),
            style: GoogleFonts.rajdhani(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _agreeToTerms,
            onChanged: (v) => setState(() => _agreeToTerms = v ?? false),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms & Conditions',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.primaryAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  recognizer: TapGestureRecognizer()..onTap = () {},
                ),
              ],
            ),
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

  Widget _buildLoginLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: GoogleFonts.rajdhani(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Log In',
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

// ─── Shared widgets ──────────────────────────────────────────────────────────

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

        final path = Path()
          ..moveTo(ox + tileW / 2, oy)
          ..lineTo(ox + tileW, oy + tileH / 2)
          ..lineTo(ox + tileW / 2, oy + tileH)
          ..lineTo(ox, oy + tileH / 2)
          ..close();
        canvas.drawPath(path, paint);

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
