import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../controllers/chat_controller.dart';
import '../../db/models/conversation_model.dart';
import '../../db/models/message_model.dart';
import '../../services/api/api_service.dart';
import '../../theme/app_colors.dart';

/// Chat Screen
///
/// Displays messages in a conversation and allows sending new messages.
class ChatScreen extends StatefulWidget {
  final ConversationModel conversation;

  const ChatScreen({super.key, required this.conversation});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatController = ChatController.instance;
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _chatController.setCurrentConversation(widget.conversation);
    if (mounted) setState(() {});
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatController.clearCurrentConversation();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final success = await _chatController.sendMessage(content);
      if (success) {
        if (mounted) {
          setState(() {});
        }
        _scrollToBottom();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to send message')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _confirmDeleteChat() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Delete chat?',
            style: GoogleFonts.rajdhani(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'This will remove this chat and its local messages from this device.',
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

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await _chatController.deleteConversation(widget.conversation);
    if (!mounted) return;

    navigator.pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Chat deleted from this device')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final myAddress = ApiService.instance.walletAddress?.toLowerCase() ?? '';
    final activeConversation =
        _chatController.currentConversation ?? widget.conversation;
    final isRequest = _chatController.isConnectionRequest(activeConversation);

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
                // Header
                _buildHeader(),
                if (isRequest) _buildRequestBanner(activeConversation),
                // Messages
                Expanded(child: _buildMessageList(myAddress)),
                // Input
                _buildMessageInput(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          // Avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primaryAccent.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.primaryAccent, width: 1),
            ),
            child: Center(
              child: Text(
                _getAvatarText(widget.conversation.peerAddress),
                style: GoogleFonts.robotoMono(
                  color: AppColors.primaryAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatAddress(widget.conversation.peerAddress),
                  style: GoogleFonts.robotoMono(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'XMTP Secure Chat',
                  style: GoogleFonts.rajdhani(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () async {
              await _chatController.loadMessagesForConversation(
                widget.conversation.topic,
              );
              setState(() {});
              _scrollToBottom();
            },
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: AppColors.textSecondary),
            color: AppColors.surface,
            onSelected: (value) async {
              if (value == 'delete_chat') {
                await _confirmDeleteChat();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'delete_chat',
                child: Text('Delete chat'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(String myAddress) {
    final messages = _chatController.currentMessages;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              color: AppColors.textHint,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'No messages yet',
              style: GoogleFonts.rajdhani(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start the conversation!',
              style: GoogleFonts.rajdhani(
                color: AppColors.textHint,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isMe = message.sender.toLowerCase() == myAddress;
        final showDateHeader =
            index == 0 ||
            !_isSameDay(messages[index - 1].sentAt, message.sentAt);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showDateHeader) _buildDateHeader(message.sentAt),
            _MessageBubble(message: message, isMe: isMe),
          ],
        );
      },
    );
  }

  Widget _buildDateHeader(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _formatDateHeader(date),
            style: GoogleFonts.rajdhani(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              style: GoogleFonts.rajdhani(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: GoogleFonts.rajdhani(
                  color: AppColors.textHint,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(
                    color: AppColors.primaryAccent,
                    width: 1,
                  ),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _isSending ? null : _handleSendMessage,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primaryAccent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.black,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.black, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestBanner(ConversationModel conversation) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'New connection',
            style: GoogleFonts.rajdhani(
              color: AppColors.primaryAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reply once and this chat will move into your main conversations.',
            style: GoogleFonts.rajdhani(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    await _chatController.declineRequest(conversation);
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text('Dismiss'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => FocusScope.of(context).unfocus(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Reply Below'),
                ),
              ),
            ],
          ),
        ],
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) return 'Today';
    if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return '${date.month}/${date.day}/${date.year}';
  }
}

/// Message bubble widget
class _MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isMe ? AppColors.primaryAccent : AppColors.surfaceVariant,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMe ? 16 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  message.content,
                  style: GoogleFonts.rajdhani(
                    color: isMe ? Colors.black : AppColors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.sentAt),
                      style: GoogleFonts.rajdhani(
                        color: isMe
                            ? Colors.black.withValues(alpha: 0.7)
                            : AppColors.textHint,
                        fontSize: 11,
                      ),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      Icon(
                        message.isSynced
                            ? Icons.done_all
                            : message.status == 'failed'
                            ? Icons.error_outline
                            : Icons.access_time,
                        size: 14,
                        color: message.isSynced
                            ? Colors.black.withValues(alpha: 0.7)
                            : message.status == 'failed'
                            ? Colors.red
                            : Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
