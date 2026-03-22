import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/chat_controller.dart';
import '../../db/models/conversation_model.dart';
import '../../theme/app_colors.dart';
import 'chat_screen.dart';

class MessageRequestsScreen extends StatefulWidget {
  const MessageRequestsScreen({super.key});

  @override
  State<MessageRequestsScreen> createState() => _MessageRequestsScreenState();
}

class _MessageRequestsScreenState extends State<MessageRequestsScreen> {
  final _chatController = ChatController.instance;
  bool _isRefreshing = false;

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _chatController.refresh();
    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  Future<void> _accept(ConversationModel conversation) async {
    await _chatController.acceptRequest(conversation);
    if (!mounted) return;
    final refreshed = _chatController.conversations.firstWhere(
      (item) => item.topic == conversation.topic,
      orElse: () => conversation,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(conversation: refreshed),
      ),
    );
  }

  Future<void> _decline(ConversationModel conversation) async {
    await _chatController.declineRequest(conversation);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request declined')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requests = _chatController.requests;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(height: 2, color: AppColors.primaryAccent),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: requests.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: AppColors.primaryAccent,
                          child: ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: requests.length,
                            itemBuilder: (context, index) {
                              final conversation = requests[index];
                              return _RequestCard(
                                conversation: conversation,
                                onAccept: () => _accept(conversation),
                                onDecline: () => _decline(conversation),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 16),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Message Requests',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Review first-time chats before opening them.',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.primaryAccent),
            onPressed: _isRefreshing ? null : _refresh,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mark_chat_unread_outlined, color: AppColors.textHint, size: 60),
          const SizedBox(height: 16),
          Text(
            'No pending requests',
            style: GoogleFonts.rajdhani(
              color: AppColors.textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'New chat requests will appear here.',
            style: GoogleFonts.rajdhani(
              color: AppColors.textHint,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final ConversationModel conversation;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _RequestCard({
    required this.conversation,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryAccent.withValues(alpha: 0.14),
                  border: Border.all(color: AppColors.primaryAccent),
                ),
                child: Center(
                  child: Text(
                    conversation.peerAddress.substring(2, 4).toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: AppColors.primaryAccent,
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
                    Text(
                      _formatAddress(conversation.peerAddress),
                      style: GoogleFonts.robotoMono(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      conversation.lastMessageAt == null
                          ? 'New request'
                          : 'Sent ${_formatTime(conversation.lastMessageAt!)}',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.textHint,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (conversation.lastMessage?.isNotEmpty ?? false) ...[
            const SizedBox(height: 14),
            Text(
              conversation.lastMessage!,
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDecline,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.border),
                    foregroundColor: AppColors.textSecondary,
                  ),
                  child: const Text('Decline'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Accept'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatAddress(String address) {
    if (address.length < 10) return address;
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inDays > 0) return '${time.month}/${time.day}';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }
}
