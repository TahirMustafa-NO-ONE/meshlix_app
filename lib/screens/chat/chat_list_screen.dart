import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/chat_controller.dart';
import '../../db/models/contact_model.dart';
import '../../db/models/conversation_model.dart';
import '../../theme/app_colors.dart';
import 'chat_screen.dart';
import 'message_requests_screen.dart';

/// Chat List Screen
///
/// Displays all conversations with last message preview.
/// Tapping a conversation opens the chat screen.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final _chatController = ChatController.instance;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _chatController.addListener(_onChatUpdate);
    _initializeController();
  }

  @override
  void dispose() {
    _chatController.removeListener(_onChatUpdate);
    super.dispose();
  }

  void _onChatUpdate() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initializeController() async {
    await _chatController.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    await _chatController.refresh();
    if (mounted) setState(() => _isRefreshing = false);
  }

  Future<void> _openChat(ConversationModel conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)),
    );
    await _chatController.refresh();
  }

  Future<void> _openContact(ContactModel contact) async {
    final conversation = await _chatController.getOrCreateConversation(
      contact.address,
    );
    if (!mounted || conversation == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatScreen(conversation: conversation)),
    );
    await _chatController.refresh();
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
                // Conversation list
                Expanded(child: _buildConversationList()),
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
                'P2P Chat • Messages',
                style: GoogleFonts.rajdhani(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          Row(
            children: [
              if (_chatController.totalRequestCount > 0)
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const MessageRequestsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.mark_chat_unread_outlined,
                    size: 18,
                    color: AppColors.primaryAccent,
                  ),
                  label: Text(
                    'Requests (${_chatController.totalRequestCount})',
                    style: GoogleFonts.rajdhani(
                      color: AppColors.primaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              IconButton(
                icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
                onPressed: _isRefreshing ? null : _handleRefresh,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    if (_chatController.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.primaryAccent),
      );
    }

    if (_chatController.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: AppColors.textSecondary, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading conversations',
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _handleRefresh,
              child: Text(
                'Retry',
                style: GoogleFonts.rajdhani(color: AppColors.primaryAccent),
              ),
            ),
          ],
        ),
      );
    }

    final conversations = _chatController.conversations;
    final contacts = _chatController.contacts;
    final conversationAddresses = conversations
        .map((conversation) => conversation.peerAddress.toLowerCase())
        .toSet();
    final contactOnlyItems = contacts
        .where(
          (contact) =>
              !conversationAddresses.contains(contact.address.toLowerCase()),
        )
        .toList();

    if (conversations.isEmpty && contactOnlyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.textHint,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'No conversations yet',
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start a new chat from the Home tab',
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
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ...conversations.map(
            (conversation) => _ConversationTile(
              conversation: conversation,
              onTap: () => _openChat(conversation),
            ),
          ),
          ...contactOnlyItems.map(
            (contact) => _ContactTile(
              contact: contact,
              onTap: () => _openContact(contact),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conversation tile widget
class _ConversationTile extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onTap;

  const _ConversationTile({required this.conversation, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasUnread = conversation.unreadCount > 0;

    return InkWell(
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
                border: Border.all(
                  color: hasUnread ? AppColors.primaryAccent : AppColors.border,
                  width: hasUnread ? 2 : 1,
                ),
              ),
              child: Center(
                child: Text(
                  _getAvatarText(conversation.peerAddress),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _formatAddress(conversation.peerAddress),
                          style: GoogleFonts.robotoMono(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.lastMessageAt != null)
                        Text(
                          _formatTime(conversation.lastMessageAt!),
                          style: GoogleFonts.rajdhani(
                            color: hasUnread
                                ? AppColors.primaryAccent
                                : AppColors.textHint,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.lastMessage ?? 'No messages yet',
                          style: GoogleFonts.rajdhani(
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryAccent,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${conversation.unreadCount}',
                            style: GoogleFonts.rajdhani(
                              color: Colors.black,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${time.month}/${time.day}';
    }

    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Now';
  }
}

class _ContactTile extends StatelessWidget {
  final ContactModel contact;
  final VoidCallback onTap;

  const _ContactTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryAccent.withValues(alpha: 0.10),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.displayName ?? _formatAddress(contact.address),
                    style: GoogleFonts.rajdhani(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact.displayName == null
                        ? 'Tap to open chat'
                        : _formatAddress(contact.address),
                    style: GoogleFonts.robotoMono(
                      color: AppColors.textHint,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chat_bubble_outline,
              color: AppColors.primaryAccent,
              size: 20,
            ),
          ],
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
}
