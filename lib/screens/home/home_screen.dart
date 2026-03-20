import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth/auth_service.dart';
import '../../controllers/chat_controller.dart';
import '../../theme/app_colors.dart';
import '../auth/auth_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _walletAddressController =
      TextEditingController();
  final _chatController = ChatController.instance;
  bool _isSendingRequest = false;

  @override
  void dispose() {
    _walletAddressController.dispose();
    super.dispose();
  }

  Future<void> _handleSendChatRequest() async {
    final address = _walletAddressController.text.trim();
    if (address.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a wallet address')),
      );
      return;
    }

    // Validate Ethereum address format
    if (!address.startsWith('0x') || address.length != 42) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid Ethereum address (0x...)'),
        ),
      );
      return;
    }

    setState(() => _isSendingRequest = true);
    try {
      // Check if the address can receive XMTP messages
      final canMessage = await _chatController.canMessage(address);
      if (!canMessage) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$address is not on XMTP network yet'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Create or get conversation
      final conversation = await _chatController.getOrCreateConversation(
        address,
      );
      if (conversation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to create conversation')),
          );
        }
        return;
      }

      // Navigate to chat screen
      if (mounted) {
        _walletAddressController.clear();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSendingRequest = false);
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  // ── Header ──────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.only(
                      bottom: 12,
                    ), // spacing above border
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
                              'P2P Chat • Home',
                              style: GoogleFonts.rajdhani(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Current User Card ────────────────────────────────
                  // Container(
                  //   width: double.infinity,
                  //   padding: const EdgeInsets.all(20),
                  //   decoration: BoxDecoration(
                  //     gradient: LinearGradient(
                  //       colors: [
                  //         AppColors.primaryAccent.withValues(alpha: 0.15),
                  //         AppColors.primaryAccent.withValues(alpha: 0.05),
                  //       ],
                  //       begin: Alignment.topLeft,
                  //       end: Alignment.bottomRight,
                  //     ),
                  //     borderRadius: BorderRadius.circular(16),
                  //     border: Border.all(
                  //       color: AppColors.primaryAccent.withValues(alpha: 0.3),
                  //     ),
                  //   ),
                  //   child: Row(
                  //     children: [
                  //       // Profile Image/Avatar
                  //       if (currentUser.profileImage != null)
                  //         Container(
                  //           width: 56,
                  //           height: 56,
                  //           decoration: BoxDecoration(
                  //             shape: BoxShape.circle,
                  //             border: Border.all(
                  //               color: AppColors.primaryAccent,
                  //               width: 2,
                  //             ),
                  //             image: DecorationImage(
                  //               image: NetworkImage(currentUser.profileImage!),
                  //               fit: BoxFit.cover,
                  //             ),
                  //           ),
                  //         )
                  //       else
                  //         Container(
                  //           width: 56,
                  //           height: 56,
                  //           decoration: BoxDecoration(
                  //             shape: BoxShape.circle,
                  //             color: AppColors.primaryAccent.withValues(
                  //               alpha: 0.2,
                  //             ),
                  //             border: Border.all(
                  //               color: AppColors.primaryAccent,
                  //               width: 2,
                  //             ),
                  //           ),
                  //           child: Center(
                  //             child: Text(
                  //               currentUser.displayName[0].toUpperCase(),
                  //               style: GoogleFonts.orbitron(
                  //                 color: AppColors.primaryAccent,
                  //                 fontSize: 24,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //             ),
                  //           ),
                  //         ),
                  //       const SizedBox(width: 16),
                  //       Expanded(
                  //         child: Column(
                  //           crossAxisAlignment: CrossAxisAlignment.start,
                  //           children: [
                  //             Text(
                  //               'Currently Signed In',
                  //               style: GoogleFonts.rajdhani(
                  //                 color: AppColors.textSecondary,
                  //                 fontSize: 12,
                  //               ),
                  //             ),
                  //             const SizedBox(height: 4),
                  //             Text(
                  //               currentUser.displayName,
                  //               style: GoogleFonts.rajdhani(
                  //                 color: AppColors.textPrimary,
                  //                 fontSize: 18,
                  //                 fontWeight: FontWeight.bold,
                  //               ),
                  //               maxLines: 1,
                  //               overflow: TextOverflow.ellipsis,
                  //             ),
                  //             const SizedBox(height: 2),
                  //             Text(
                  //               currentUser.providerDisplayName,
                  //               style: GoogleFonts.rajdhani(
                  //                 color: AppColors.primaryAccent,
                  //                 fontSize: 12,
                  //               ),
                  //             ),
                  //           ],
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                  // ),
                  // const SizedBox(height: 40),
                  // const SizedBox(height: 40),

                  // ── New Chat Section ─────────────────────────────────
                  Text(
                    'Start a New Chat',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the recipient\'s wallet address to send a chat request.',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Wallet Address Input
                  TextField(
                    controller: _walletAddressController,
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                    ),
                    decoration: InputDecoration(
                      hintText: '0x000...0000',
                      hintStyle: GoogleFonts.robotoMono(
                        color: AppColors.textHint,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: AppColors.textHint,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primaryAccent,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Send Chat Request Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSendingRequest
                          ? null
                          : _handleSendChatRequest,
                      icon: _isSendingRequest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Icon(
                              Icons.send_rounded,
                              size: 18,
                              color: Colors.black,
                            ),
                      label: Text(
                        _isSendingRequest ? 'Sending...' : 'Send Chat Request',
                        style: GoogleFonts.rajdhani(
                          color: Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryAccent,
                        disabledBackgroundColor: AppColors.primaryAccent
                            .withValues(alpha: 0.5),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Container(height: 1, color: AppColors.border),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
