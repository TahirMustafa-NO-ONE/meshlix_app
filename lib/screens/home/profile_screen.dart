import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/app_init_service.dart';
import '../../services/auth/auth_service.dart';
import '../../services/storage/private_key_storage.dart';
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
      final walletAddress = AuthService.instance.currentUser?.publicAddress;
      final privateKey = walletAddress == null
          ? null
          : await PrivateKeyStorage.instance.loadPrivateKey(walletAddress);
      if (!mounted) return;
      setState(() {
        _privateKey = privateKey;
        _isLoadingPrivateKey = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingPrivateKey = false);
    }
  }

  void _togglePrivateKeyVisibility() {
    setState(() => _isPrivateKeyVisible = !_isPrivateKeyVisible);
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AuthScreen()),
        );
      });
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MESHLIX',
                    style: GoogleFonts.orbitron(
                      color: AppColors.primaryAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3,
                    ),
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
              const SizedBox(height: 32),
              _buildCard(
                title: 'Wallet Address',
                icon: Icons.account_balance_wallet_outlined,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.publicAddress,
                        style: GoogleFonts.robotoMono(
                          color: AppColors.primaryAccent,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded),
                      color: AppColors.primaryAccent,
                      onPressed: () {
                        Clipboard.setData(
                          ClipboardData(text: user.publicAddress),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _buildCard(
                title: 'Private Key',
                icon: Icons.key_outlined,
                accentColor: AppColors.error,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stored locally in secure storage and never in SharedPreferences.',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoadingPrivateKey)
                      const Center(child: CircularProgressIndicator())
                    else ...[
                      Text(
                        _isPrivateKeyVisible && _privateKey != null
                            ? _privateKey!
                            : '•' * 64,
                        style: GoogleFonts.robotoMono(
                          color: _isPrivateKeyVisible
                              ? AppColors.error
                              : AppColors.textHint,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: _togglePrivateKeyVisibility,
                            icon: Icon(
                              _isPrivateKeyVisible
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                            ),
                            label: Text(_isPrivateKeyVisible ? 'Hide' : 'Show'),
                          ),
                          if (_isPrivateKeyVisible && _privateKey != null)
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: _privateKey!),
                                );
                              },
                              icon: const Icon(Icons.copy_rounded),
                              label: const Text('Copy'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required Widget child,
    Color accentColor = AppColors.primaryAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: accentColor),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.rajdhani(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Future<void> _handleSignOut(BuildContext context) async {
    await AppInitService.instance.shutdown();
    await AuthService.instance.signOut();

    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthScreen()),
      (route) => false,
    );
  }
}
