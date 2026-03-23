import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/chat_controller.dart';
import '../../db/models/contact_model.dart';
import '../../theme/app_colors.dart';
import '../chat/chat_screen.dart';

/// Contacts Screen
///
/// Displays all contacts (addresses the user has chatted with).
/// Allows starting a new chat with a contact.
class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _chatController = ChatController.instance;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    await _chatController.loadContacts();
    if (mounted) setState(() {});
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _chatController.loadContacts();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _startChat(ContactModel contact) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.primaryAccent),
              const SizedBox(height: 16),
              Text(
                'Opening chat...',
                style: GoogleFonts.rajdhani(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final conversation = await _chatController.getOrCreateConversation(
        contact.address,
      );
      if (mounted) Navigator.of(context).pop(); // Close loading dialog

      if (conversation != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(conversation: conversation),
          ),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Failed to open chat')));
        }
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop(); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _confirmDeleteContact(ContactModel contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Delete contact?',
            style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will remove the contact and any local chat history for this address.',
            style: GoogleFonts.rajdhani(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    await _chatController.deleteContact(contact);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Contact deleted from this device')),
    );
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
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(),
                // Contacts list
                Expanded(child: _buildContactList()),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.primaryAccent, width: 1),
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
            icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
            onPressed: _isRefreshing ? null : _handleRefresh,
          ),
        ],
      ),
    );
  }

  Widget _buildContactList() {
    final contacts = _chatController.contacts;

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: AppColors.textHint, size: 64),
            const SizedBox(height: 16),
            Text(
              'No contacts yet',
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Contacts are added when you chat',
              style: GoogleFonts.rajdhani(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: AppColors.primaryAccent,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: contacts.length,
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return _ContactTile(
            contact: contact,
            onTap: () => _startChat(contact),
            onDelete: () => _confirmDeleteContact(contact),
          );
        },
      ),
    );
  }
}

/// Contact tile widget
class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ContactTile({
    required this.contact,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(contact.address),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        color: Colors.red.withValues(alpha: 0.18),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryAccent.withValues(alpha: 0.15),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Center(
                  child: Text(
                    _getAvatarText(contact.address),
                    style: GoogleFonts.robotoMono(
                      color: AppColors.primaryAccent,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      contact.displayName ?? _formatAddress(contact.address),
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (contact.displayName != null)
                      Text(
                        _formatAddress(contact.address),
                        style: GoogleFonts.robotoMono(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    if (contact.lastInteractionAt != null)
                      Text(
                        'Last chat: ${_formatTime(contact.lastInteractionAt!)}',
                        style: GoogleFonts.rajdhani(
                          color: AppColors.textHint,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              // Chat button
              Icon(
                Icons.chat_bubble_outline,
                color: AppColors.primaryAccent,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getAvatarText(String address) {
    if (address.length < 6) return '??';
    return address.substring(2, 4).toUpperCase();
  }

  String _formatAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays > 0) {
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';
      return '${time.month}/${time.day}';
    }

    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
  }
}
