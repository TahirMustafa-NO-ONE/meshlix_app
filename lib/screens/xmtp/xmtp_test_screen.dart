import 'package:flutter/material.dart';
import '../../services/xmtp/xmtp_service.dart';
import 'package:xmtp/xmtp.dart' as xmtp;

/// Test screen for XMTP functionality
///
/// This screen demonstrates:
/// - Initializing XMTP client
/// - Sending test messages
/// - Receiving messages in real-time
/// - Listing conversations
///
/// Usage:
/// 1. User must be authenticated first (via Web3Auth)
/// 2. Navigate to this screen
/// 3. Initialize XMTP client
/// 4. Test sending/receiving messages
class XmtpTestScreen extends StatefulWidget {
  const XmtpTestScreen({super.key});

  @override
  State<XmtpTestScreen> createState() => _XmtpTestScreenState();
}

class _XmtpTestScreenState extends State<XmtpTestScreen> {
  final _xmtpService = XmtpService.instance;
  final _recipientController = TextEditingController();
  final _messageController = TextEditingController();

  bool _isInitializing = false;
  bool _isSending = false;
  final List<xmtp.DecodedMessage> _receivedMessages = [];
  List<xmtp.Conversation> _conversations = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenToMessages();
  }

  @override
  void dispose() {
    _recipientController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  // Listen to incoming messages
  void _listenToMessages() {
    _xmtpService.messageStream.listen(
      (message) {
        setState(() {
          _receivedMessages.insert(0, message);
        });
        _showSnackBar('New message from ${message.sender}');
      },
      onError: (error) {
        _showSnackBar('Message stream error: $error', isError: true);
      },
    );
  }

  // Initialize XMTP client
  Future<void> _initializeXmtp() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      await _xmtpService.initialize(
        useProduction: false, // Use dev environment for testing
      );

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
        _showSnackBar('XMTP initialized successfully!');

        // Load conversations after initialization
        await _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _errorMessage = e.toString();
        });
        _showSnackBar('Failed to initialize: $e', isError: true);
      }
    }
  }

  // Send a test message
  Future<void> _sendMessage() async {
    final recipient = _recipientController.text.trim();
    final message = _messageController.text.trim();

    if (recipient.isEmpty || message.isEmpty) {
      _showSnackBar(
        'Please enter recipient address and message',
        isError: true,
      );
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      await _xmtpService.sendMessage(
        recipientAddress: recipient,
        message: message,
      );

      if (mounted) {
        setState(() {
          _isSending = false;
          _messageController.clear();
        });
        _showSnackBar('Message sent successfully!');

        // Reload conversations
        await _loadConversations();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
          _errorMessage = e.toString();
        });
        _showSnackBar('Failed to send: $e', isError: true);
      }
    }
  }

  // Load all conversations
  Future<void> _loadConversations() async {
    try {
      final conversations = await _xmtpService.listConversations();
      if (mounted) {
        setState(() {
          _conversations = conversations;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load conversations: $e', isError: true);
    }
  }

  // Check if an address can receive messages
  Future<void> _checkCanMessage() async {
    final address = _recipientController.text.trim();
    if (address.isEmpty) {
      _showSnackBar('Please enter an address', isError: true);
      return;
    }

    try {
      final canMessage = await _xmtpService.canMessage(address);
      _showSnackBar(
        canMessage
            ? 'Address can receive XMTP messages ✓'
            : 'Address is not on XMTP network ✗',
      );
    } catch (e) {
      _showSnackBar('Failed to check: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInitialized = _xmtpService.isInitialized;

    return Scaffold(
      appBar: AppBar(
        title: const Text('XMTP Test'),
        actions: [
          if (isInitialized)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadConversations,
              tooltip: 'Refresh conversations',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Initialization Section
            _buildInitializationSection(isInitialized),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            if (isInitialized) ...[
              // Send Message Section
              _buildSendMessageSection(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Conversations Section
              _buildConversationsSection(),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // Received Messages Section
              _buildReceivedMessagesSection(),
            ],

            // Error Display
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInitializationSection(bool isInitialized) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '1. Initialize XMTP Client',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (isInitialized) ...[
              const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    'XMTP Client Initialized',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Wallet: ${_xmtpService.walletAddress ?? "Unknown"}',
                style: const TextStyle(fontSize: 12),
              ),
            ] else ...[
              const Text(
                'Initialize the XMTP client using your Web3Auth private key.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _isInitializing ? null : _initializeXmtp,
                child: _isInitializing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Initialize XMTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSendMessageSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '2. Send Test Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientController,
              decoration: const InputDecoration(
                labelText: 'Recipient Wallet Address',
                hintText: '0x...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _checkCanMessage,
                    icon: const Icon(Icons.search, size: 16),
                    label: const Text('Check Address'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText: 'Enter your message...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isSending ? null : _sendMessage,
              child: _isSending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Message'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConversationsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '3. Conversations',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_conversations.isEmpty)
              const Text('No conversations yet')
            else
              ..._conversations.map(
                (convo) => ListTile(
                  leading: const Icon(Icons.chat),
                  title: Text(convo.peer.hex),
                  subtitle: Text('Topic: ${convo.topic}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceivedMessagesSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '4. Received Messages (Real-time)',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_receivedMessages.isEmpty)
              const Text('No messages received yet')
            else
              ..._receivedMessages
                  .take(10)
                  .map(
                    (message) => Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const Icon(Icons.message),
                        title: Text(message.sender.hex),
                        subtitle: Text(
                          message.content.toString(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Text(
                          message.sentAt.toLocal().toString().substring(0, 19),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
