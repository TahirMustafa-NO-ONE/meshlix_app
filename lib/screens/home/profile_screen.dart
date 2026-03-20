import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth/auth_service.dart';
import '../../services/session/session_manager.dart';
import '../../services/app_init_service.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isPrivateKeyVisible = false;
  String? _privateKey;
  bool _isLoadingPrivateKey = false;

  @override
  void initState() {
    super.initState();
    _loadPrivateKey();
  }

  Future<void> _loadPrivateKey() async {
    setState(() => _isLoadingPrivateKey = true);
    try {
      final privateKey = await SessionManager.instance.getAuthToken();
      if (mounted) {
        setState(() {
          _privateKey = privateKey;
          _isLoadingPrivateKey = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingPrivateKey = false);
      }
    }
  }

  void _togglePrivateKeyVisibility() {
    setState(() => _isPrivateKeyVisible = !_isPrivateKeyVisible);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      // Fallback - should not happen
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

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
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ──────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: AppColors.primaryAccent,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MESHLIX',
                                style: GoogleFonts.orbitron(
                                  color: AppColors.primaryAccent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3.0,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'P2P Chat • Profile',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.logout_rounded,
                              color: AppColors.error,
                            ),
                            onPressed: () => _handleSignOut(context),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // ── Welcome Message ────────────────────────────────────
                    Row(
                      children: [
                        // Profile Image
                        if (user.profileImage != null)
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryAccent,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(user.profileImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryAccent.withValues(
                                alpha: 0.2,
                              ),
                              border: Border.all(
                                color: AppColors.primaryAccent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                user.displayName[0].toUpperCase(),
                                style: GoogleFonts.orbitron(
                                  color: AppColors.primaryAccent,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome Back',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.displayName,
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textPrimary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),

                    // ── Wallet Card ────────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.primaryAccent.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGlow,
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryAccent.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.account_balance_wallet_outlined,
                                  color: AppColors.primaryAccent,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Your Wallet Address',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.publicAddress,
                                      style: GoogleFonts.robotoMono(
                                        color: AppColors.primaryAccent,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      user.shortAddress,
                                      style: GoogleFonts.rajdhani(
                                        color: AppColors.textHint,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(
                                  Icons.copy_rounded,
                                  color: AppColors.primaryAccent,
                                  size: 20,
                                ),
                                onPressed: () {
                                  Clipboard.setData(
                                    ClipboardData(text: user.publicAddress),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Address copied to clipboard',
                                        style: GoogleFonts.rajdhani(
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF1E3A00),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      margin: const EdgeInsets.all(16),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Private Key Card ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.1),
                            blurRadius: 12,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.error.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.key_outlined,
                                  color: AppColors.error,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Your Private Key',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Warning message
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: AppColors.error,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Never share your private key with anyone!',
                                    style: GoogleFonts.rajdhani(
                                      color: AppColors.error,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: _isLoadingPrivateKey
                                    ? const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.textHint,
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _isPrivateKeyVisible &&
                                                    _privateKey != null
                                                ? _privateKey!
                                                : '••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••••',
                                            style: GoogleFonts.robotoMono(
                                              color: _isPrivateKeyVisible
                                                  ? AppColors.error
                                                  : AppColors.textHint,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            children: [
                                              // Toggle visibility button
                                              TextButton.icon(
                                                onPressed:
                                                    _togglePrivateKeyVisibility,
                                                icon: Icon(
                                                  _isPrivateKeyVisible
                                                      ? Icons.visibility_off
                                                      : Icons.visibility,
                                                  size: 16,
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                                label: Text(
                                                  _isPrivateKeyVisible
                                                      ? 'Hide'
                                                      : 'Show',
                                                  style: GoogleFonts.rajdhani(
                                                    color:
                                                        AppColors.textSecondary,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                style: TextButton.styleFrom(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 8,
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // Copy button
                                              if (_isPrivateKeyVisible &&
                                                  _privateKey != null)
                                                TextButton.icon(
                                                  onPressed: () {
                                                    Clipboard.setData(
                                                      ClipboardData(
                                                        text: _privateKey!,
                                                      ),
                                                    );
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          'Private key copied to clipboard',
                                                          style:
                                                              GoogleFonts.rajdhani(
                                                                color: AppColors
                                                                    .textPrimary,
                                                              ),
                                                        ),
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF3D1100,
                                                            ),
                                                        behavior:
                                                            SnackBarBehavior
                                                                .floating,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                        margin:
                                                            const EdgeInsets.all(
                                                              16,
                                                            ),
                                                        duration:
                                                            const Duration(
                                                              seconds: 2,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  icon: const Icon(
                                                    Icons.copy_rounded,
                                                    size: 16,
                                                    color: AppColors.error,
                                                  ),
                                                  label: Text(
                                                    'Copy',
                                                    style: GoogleFonts.rajdhani(
                                                      color: AppColors.error,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                  style: TextButton.styleFrom(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── User Info Card ─────────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.account_circle_outlined,
                                color: AppColors.primaryAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Account Details',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Display Name
                          if (user.name != null) ...[
                            _InfoRow(label: 'Name', value: user.name!),
                            const SizedBox(height: 12),
                          ],

                          // Username
                          _InfoRow(label: 'Username', value: user.username),
                          const SizedBox(height: 12),

                          // Email
                          if (user.email != null) ...[
                            _InfoRow(label: 'Email', value: user.email!),
                            const SizedBox(height: 12),
                          ],

                          // Provider
                          _InfoRow(
                            label: 'Provider',
                            value: user.providerDisplayName,
                          ),
                          const SizedBox(height: 12),

                          // Verifier (Web3Auth specific)
                          if (user.verifier != null) ...[
                            _InfoRow(label: 'Verifier', value: user.verifier!),
                            const SizedBox(height: 12),
                          ],

                          // Type of Login
                          if (user.typeOfLogin != null) ...[
                            _InfoRow(
                              label: 'Login Type',
                              value: user.typeOfLogin!,
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Verifier ID (shortened)
                          if (user.verifierId != null) ...[
                            _InfoRow(
                              label: 'Verifier ID',
                              value: user.verifierId!.length > 30
                                  ? '${user.verifierId!.substring(0, 30)}...'
                                  : user.verifierId!,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Web3Auth Info Card ─────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.info_outline,
                                color: AppColors.primaryAccent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Authentication Info',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your account is secured by Web3Auth\'s non-custodial authentication. Your private key is split across multiple nodes and can only be reconstructed with your login credentials.',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Footer ─────────────────────────────────────────────
                    Center(
                      child: Column(
                        children: [
                          Text(
                            'Secured by Web3Auth',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textHint,
                              fontSize: 12,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Non-custodial • Multi-factor • Decentralized',
                            style: GoogleFonts.rajdhani(
                              color: AppColors.textHint,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    // Dispose app services first (XMTP, DB, Sync)
    await AppInitService.instance.dispose();

    // Then sign out from auth
    await AuthService.instance.signOut();

    if (context.mounted) {
      // Use pushAndRemoveUntil to clear all previous routes from the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false, // Remove all previous routes
      );
    }
  }
}

// ─── Info Row Widget ─────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(color: AppColors.textHint, fontSize: 13),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
