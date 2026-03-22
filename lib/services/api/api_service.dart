import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'backend_config.dart';
import '../session/session_manager.dart';
import '../storage/private_key_storage.dart';

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  String? _walletAddress;
  String? _sessionToken;

  Future<void> initialize({
    required String walletAddress,
    required String privateKey,
  }) async {
    _walletAddress = walletAddress;

    final response = await http.post(
      Uri.parse('${BackendConfig.httpBaseUrl}/session/init'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'walletAddress': walletAddress,
        'privateKey': privateKey,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to initialize backend session: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _sessionToken = data['sessionToken'] as String;
    await SessionManager.instance.saveBackendSessionToken(_sessionToken!);
    debugPrint('[ApiService] Backend session initialized for $walletAddress');
  }

  Future<BackendMessage> sendMessage({
    required String recipientAddress,
    required String message,
  }) async {
    _ensureInitialized();

    var response = await http.post(
      Uri.parse('${BackendConfig.httpBaseUrl}/send-message'),
      headers: _headers(),
      body: jsonEncode({
        'recipientAddress': recipientAddress,
        'message': message,
      }),
    );

    if (response.statusCode == 401) {
      await _reinitializeSession();
      response = await http.post(
        Uri.parse('${BackendConfig.httpBaseUrl}/send-message'),
        headers: _headers(),
        body: jsonEncode({
          'recipientAddress': recipientAddress,
          'message': message,
        }),
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to send message: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BackendMessage.fromJson(data['message'] as Map<String, dynamic>);
  }

  Future<List<BackendMessage>> getMessages({
    required String peerAddress,
    DateTime? since,
  }) async {
    _ensureInitialized();

    final queryParameters = <String, String>{'peerAddress': peerAddress};
    if (since != null) {
      queryParameters['since'] = since.toIso8601String();
    }

    final uri = Uri.parse('${BackendConfig.httpBaseUrl}/messages')
        .replace(queryParameters: queryParameters);
    var response = await http.get(uri, headers: _headers(includeJson: false));

    if (response.statusCode == 401) {
      await _reinitializeSession();
      response = await http.get(uri, headers: _headers(includeJson: false));
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch messages: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final messages = data['messages'] as List<dynamic>;
    return messages
        .map((json) => BackendMessage.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<BackendConversation>> getConversations() async {
    _ensureInitialized();

    var response = await http.get(
      Uri.parse('${BackendConfig.httpBaseUrl}/conversations'),
      headers: _headers(includeJson: false),
    );

    if (response.statusCode == 401) {
      await _reinitializeSession();
      response = await http.get(
        Uri.parse('${BackendConfig.httpBaseUrl}/conversations'),
        headers: _headers(includeJson: false),
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch conversations: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final conversations = data['conversations'] as List<dynamic>;
    return conversations
        .map(
          (json) => BackendConversation.fromJson(json as Map<String, dynamic>),
        )
        .toList();
  }

  Future<BackendConversation> updateConversationConsent({
    required String peerAddress,
    required String consentState,
  }) async {
    _ensureInitialized();

    var response = await http.post(
      Uri.parse('${BackendConfig.httpBaseUrl}/conversations/consent'),
      headers: _headers(),
      body: jsonEncode({
        'peerAddress': peerAddress,
        'consentState': consentState,
      }),
    );

    if (response.statusCode == 401) {
      await _reinitializeSession();
      response = await http.post(
        Uri.parse('${BackendConfig.httpBaseUrl}/conversations/consent'),
        headers: _headers(),
        body: jsonEncode({
          'peerAddress': peerAddress,
          'consentState': consentState,
        }),
      );
    }

    if (response.statusCode != 200) {
      throw Exception('Failed to update conversation consent: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return BackendConversation.fromJson(
      data['conversation'] as Map<String, dynamic>,
    );
  }

  Future<bool> canMessage(String targetAddress) async {
    _ensureInitialized();

    final uri = Uri.parse('${BackendConfig.httpBaseUrl}/can-message').replace(
      queryParameters: {'targetAddress': targetAddress},
    );

    var response = await http.get(uri, headers: _headers(includeJson: false));
    if (response.statusCode == 401) {
      await _reinitializeSession();
      response = await http.get(uri, headers: _headers(includeJson: false));
    }
    if (response.statusCode != 200) {
      return false;
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['canMessage'] as bool? ?? false;
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${BackendConfig.httpBaseUrl}/health'),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> dispose() async {
    final token = _sessionToken;
    try {
      if (token != null) {
        await http.post(
          Uri.parse('${BackendConfig.httpBaseUrl}/session/disconnect'),
          headers: _headers(),
        );
      }
    } catch (e) {
      debugPrint('[ApiService] Disconnect error: $e');
    } finally {
      _walletAddress = null;
      _sessionToken = null;
      await SessionManager.instance.clearBackendSessionToken();
    }
  }

  Map<String, String> _headers({bool includeJson = true}) {
    final headers = <String, String>{
      'Authorization': 'Bearer $_sessionToken',
    };
    if (includeJson) {
      headers['Content-Type'] = 'application/json';
    }
    return headers;
  }

  void _ensureInitialized() {
    if (_walletAddress == null || _sessionToken == null) {
      throw Exception('ApiService not initialized. Call initialize() first.');
    }
  }

  Future<void> _reinitializeSession() async {
    final walletAddress = _walletAddress;
    if (walletAddress == null) {
      throw Exception('Cannot reinitialize backend session without wallet address.');
    }

    final privateKey = await PrivateKeyStorage.instance.loadPrivateKey(walletAddress);
    if (privateKey == null || privateKey.isEmpty) {
      throw Exception('No private key found for wallet: $walletAddress');
    }

    debugPrint('[ApiService] Backend session expired, reinitializing...');
    await initialize(walletAddress: walletAddress, privateKey: privateKey);
  }

  bool get isInitialized => _walletAddress != null && _sessionToken != null;
  String? get walletAddress => _walletAddress;
  String? get sessionToken => _sessionToken;
}

class BackendMessage {
  final String id;
  final String content;
  final String sender;
  final DateTime sentAt;
  final String? conversationTopic;
  final String? recipient;
  final String? status;
  final String consentState;

  BackendMessage({
    required this.id,
    required this.content,
    required this.sender,
    required this.sentAt,
    this.conversationTopic,
    this.recipient,
    this.status,
    this.consentState = 'allowed',
  });

  factory BackendMessage.fromJson(Map<String, dynamic> json) {
    return BackendMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      sender: json['sender'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String),
      conversationTopic: json['conversationTopic'] as String?,
      recipient: json['recipient'] as String?,
      status: json['status'] as String?,
      consentState: json['consentState'] as String? ?? 'allowed',
    );
  }
}

class BackendConversation {
  final String topic;
  final String peerAddress;
  final DateTime createdAt;
  final BackendMessage? lastMessage;
  final String consentState;

  BackendConversation({
    required this.topic,
    required this.peerAddress,
    required this.createdAt,
    this.lastMessage,
    this.consentState = 'allowed',
  });

  factory BackendConversation.fromJson(Map<String, dynamic> json) {
    return BackendConversation(
      topic: json['topic'] as String,
      peerAddress: json['peerAddress'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastMessage: json['lastMessage'] == null
          ? null
          : BackendMessage.fromJson(json['lastMessage'] as Map<String, dynamic>),
      consentState: json['consentState'] as String? ?? 'allowed',
    );
  }
}
