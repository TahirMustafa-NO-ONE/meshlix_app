import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';

// ─── Model ──────────────────────────────────────────────────────────────────

class _WalletOption {
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color tileColor;

  const _WalletOption({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.tileColor,
  });
}

const _wallets = [
  _WalletOption(
    id: 'metamask',
    name: 'MetaMask',
    description: 'The most popular Ethereum wallet',
    icon: FontAwesomeIcons.ethereum,
    iconColor: Color(0xFFE2761B),
    tileColor: Color(0xFF1A1200),
  ),
  _WalletOption(
    id: 'trust',
    name: 'Trust Wallet',
    description: 'Multi-chain wallet & DApps browser',
    icon: FontAwesomeIcons.shieldHalved,
    iconColor: Color(0xFF3375BB),
    tileColor: Color(0xFF001020),
  ),
  _WalletOption(
    id: 'rainbow',
    name: 'Rainbow',
    description: 'Fun & friendly Ethereum wallet',
    icon: FontAwesomeIcons.circleHalfStroke,
    iconColor: Color(0xFF7A44F0),
    tileColor: Color(0xFF0E0020),
  ),
  _WalletOption(
    id: 'coinbase',
    name: 'Coinbase Wallet',
    description: 'Self-custody wallet by Coinbase',
    icon: FontAwesomeIcons.coins,
    iconColor: Color(0xFF1652F0),
    tileColor: Color(0xFF000B1E),
  ),
];

// ─── Bottom Sheet ────────────────────────────────────────────────────────────

/// Shows a modal bottom sheet with available wallet options.
/// Returns the selected wallet ID string, or `null` if dismissed.
///
/// Hook up [onWalletSelected] in the parent screen to call
/// [AuthService.instance.signInWithWallet(walletId)].
class WalletConnectSheet extends StatelessWidget {
  final void Function(String walletId) onWalletSelected;

  const WalletConnectSheet({super.key, required this.onWalletSelected});

  /// Convenience static method to show the sheet and await the result.
  static Future<String?> show(BuildContext context) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) =>
          WalletConnectSheet(onWalletSelected: (id) => Navigator.pop(ctx, id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: AppColors.primaryAccent, width: 1.5),
          left: BorderSide(color: AppColors.border, width: 0.5),
          right: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Drag handle ──────────────────────────────────────────────
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentGlow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppColors.primaryAccent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CONNECT WALLET',
                        style: GoogleFonts.orbitron(
                          color: AppColors.primaryAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                      ),
                      Text(
                        'Sign in with your crypto wallet',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            Divider(
              color: AppColors.border,
              height: 1,
              indent: 0,
              endIndent: 0,
            ),
            const SizedBox(height: 4),

            // ── Wallet list ──────────────────────────────────────────────
            ..._wallets.map(
              (w) =>
                  _WalletTile(wallet: w, onTap: () => onWalletSelected(w.id)),
            ),

            // ── WalletConnect generic option ──────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => onWalletSelected('walletconnect'),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF3B99FC,
                              ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.qr_code_rounded,
                              color: Color(0xFF3B99FC),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'WalletConnect',
                                  style: GoogleFonts.rajdhani(
                                    color: AppColors.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Scan QR with any compatible wallet',
                                  style: GoogleFonts.rajdhani(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SCAN',
                              style: GoogleFonts.rajdhani(
                                color: AppColors.background,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // ── Disclaimer ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 13,
                    color: AppColors.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Only connect wallets you own and control.',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textHint,
                        fontSize: 11,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ─── Wallet Tile ─────────────────────────────────────────────────────────────

class _WalletTile extends StatelessWidget {
  final _WalletOption wallet;
  final VoidCallback onTap;

  const _WalletTile({required this.wallet, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          child: Row(
            children: [
              // Wallet icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: wallet.tileColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: wallet.iconColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Center(
                  child: FaIcon(wallet.icon, color: wallet.iconColor, size: 19),
                ),
              ),
              const SizedBox(width: 14),

              // Name + description
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wallet.name,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      wallet.description,
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
