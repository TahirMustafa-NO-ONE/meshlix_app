import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth/auth_service.dart';
import '../../services/auth/auth_user.dart';
import '../../services/storage/user_storage.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<AuthUser> _allUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await UserStorage.instance.getAllUsers();
      setState(() {
        _allUsers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading users: $e')));
      }
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut();
    if (mounted) {
      // Use pushAndRemoveUntil to clear all previous routes from the stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false, // Remove all previous routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = AuthService.instance.currentUser;

    if (currentUser == null) {
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
            child: Column(
              children: [
                // ── Header ─────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.all(24.0),
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
                            'P2P Chat • Contacts',
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
                        onPressed: _handleSignOut,
                      ),
                    ],
                  ),
                ),

                // ── Current User Card ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primaryAccent.withValues(alpha: 0.15),
                          AppColors.primaryAccent.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primaryAccent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        // Profile Image/Avatar
                        if (currentUser.profileImage != null)
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primaryAccent,
                                width: 2,
                              ),
                              image: DecorationImage(
                                image: NetworkImage(currentUser.profileImage!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 56,
                            height: 56,
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
                                currentUser.displayName[0].toUpperCase(),
                                style: GoogleFonts.orbitron(
                                  color: AppColors.primaryAccent,
                                  fontSize: 24,
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
                                'Currently Signed In',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                currentUser.displayName,
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                currentUser.providerDisplayName,
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.primaryAccent,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // ── All Users Section ──────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'All Contacts (${_allUsers.length})',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(
                          Icons.refresh,
                          size: 16,
                          color: AppColors.primaryAccent,
                        ),
                        label: Text(
                          'Refresh',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.primaryAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Users List ─────────────────────────────────────────
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primaryAccent,
                          ),
                        )
                      : _allUsers.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 64,
                                color: AppColors.textHint,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No contacts yet',
                                style: GoogleFonts.rajdhani(
                                  color: AppColors.textSecondary,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadUsers,
                          color: AppColors.primaryAccent,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24.0,
                              vertical: 8.0,
                            ),
                            itemCount: _allUsers.length,
                            itemBuilder: (context, index) {
                              final user = _allUsers[index];
                              final isCurrentUser =
                                  user.publicAddress ==
                                  currentUser.publicAddress;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: _UserCard(
                                  user: user,
                                  isCurrentUser: isCurrentUser,
                                ),
                              );
                            },
                          ),
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

// ─── User Card Widget ────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final AuthUser user;
  final bool isCurrentUser;

  const _UserCard({required this.user, required this.isCurrentUser});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primaryAccent.withValues(alpha: 0.1)
            : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrentUser
              ? AppColors.primaryAccent.withValues(alpha: 0.5)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          if (user.profileImage != null)
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCurrentUser
                      ? AppColors.primaryAccent
                      : AppColors.textHint,
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCurrentUser
                    ? AppColors.primaryAccent.withValues(alpha: 0.2)
                    : AppColors.textHint.withValues(alpha: 0.2),
                border: Border.all(
                  color: isCurrentUser
                      ? AppColors.primaryAccent
                      : AppColors.textHint,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  user.displayName[0].toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: isCurrentUser
                        ? AppColors.primaryAccent
                        : AppColors.textHint,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.displayName,
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryAccent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: GoogleFonts.rajdhani(
                            color: AppColors.primaryAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                if (user.email != null)
                  Text(
                    user.email!,
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      _getProviderIcon(user.provider),
                      size: 12,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      user.providerDisplayName,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: TextStyle(color: AppColors.textHint)),
                    const SizedBox(width: 8),
                    Text(
                      user.shortAddress,
                      style: GoogleFonts.robotoMono(
                        color: AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getProviderIcon(AuthProvider provider) {
    switch (provider) {
      case AuthProvider.google:
        return Icons.g_mobiledata;
      case AuthProvider.emailOTP:
        return Icons.email_outlined;
      case AuthProvider.wallet:
      case AuthProvider.externalWallet:
        return Icons.account_balance_wallet_outlined;
      default:
        return Icons.person_outline;
    }
  }
}
