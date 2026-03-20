import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../api/backend_config.dart';
import '../api/api_service.dart';
import '../session/session_manager.dart';

class SocketService {
  SocketService._();
  static final SocketService instance = SocketService._();

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  String? _sessionToken;
  bool _isConnected = false;
  bool _isConnecting = false;

  final _messageStreamController = StreamController<BackendMessage>.broadcast();
  final _statusStreamController = StreamController<MessageStatus>.broadcast();
  final _connectionStreamController = StreamController<bool>.broadcast();

  Stream<BackendMessage> get messageStream => _messageStreamController.stream;
  Stream<MessageStatus> get statusStream => _statusStreamController.stream;
  Stream<bool> get connectionStream => _connectionStreamController.stream;

  Timer? _reconnectTimer;
  Timer? _pingTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 3);

  bool get isConnected => _isConnected;

  Future<void> connect({String? sessionToken}) async {
    if (_isConnected || _isConnecting) return;

    _sessionToken =
        sessionToken ?? await SessionManager.instance.getBackendSessionToken();
    if (_sessionToken == null) {
      throw Exception('No backend session token found.');
    }

    _isConnecting = true;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(BackendConfig.wsBaseUrl));
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnect,
      );

      await Future.delayed(const Duration(milliseconds: 300));
      _register();
      _isConnected = true;
      _isConnecting = false;
      _reconnectAttempts = 0;
      _connectionStreamController.add(true);
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      _connectionStreamController.add(false);
      _scheduleReconnect();
      rethrow;
    }
  }

  void _register() {
    if (_channel == null || _sessionToken == null) return;
    _channel!.sink.add(
      jsonEncode({'type': 'register', 'sessionToken': _sessionToken}),
    );
  }

  Future<void> disconnect() async {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _isConnected = false;
    _isConnecting = false;
    _connectionStreamController.add(false);
  }

  void _handleMessage(dynamic data) {
    try {
      final message = jsonDecode(data.toString()) as Map<String, dynamic>;
      switch (message['type'] as String?) {
        case 'new_message':
          _messageStreamController.add(
            BackendMessage.fromJson(message['data'] as Map<String, dynamic>),
          );
          break;
        case 'message_status':
          _statusStreamController.add(
            MessageStatus.fromJson(message['data'] as Map<String, dynamic>),
          );
          break;
        case 'error':
          debugPrint('[SocketService] Server error: ${message['message']}');
          break;
      }
    } catch (e) {
      debugPrint('[SocketService] Failed to handle message: $e');
    }
  }

  void _handleError(Object error) {
    debugPrint('[SocketService] WebSocket error: $error');
    _isConnected = false;
    _connectionStreamController.add(false);
    _scheduleReconnect();
  }

  void _handleDisconnect() {
    debugPrint('[SocketService] WebSocket disconnected');
    _isConnected = false;
    _connectionStreamController.add(false);
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) return;
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectAttempts++;
    _reconnectTimer = Timer(_reconnectDelay, () async {
      if (_sessionToken != null && !_isConnected) {
        try {
          await connect(sessionToken: _sessionToken);
        } catch (e) {
          debugPrint('[SocketService] Reconnect failed: $e');
        }
      }
    });
  }

  void ping() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'ping'}));
  }

  void startPing({Duration interval = const Duration(seconds: 30)}) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(interval, (_) => ping());
  }

  void stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<void> dispose() async {
    stopPing();
    await disconnect();
    await _messageStreamController.close();
    await _statusStreamController.close();
    await _connectionStreamController.close();
  }
}

class MessageStatus {
  final String id;
  final String status;
  final DateTime timestamp;

  MessageStatus({
    required this.id,
    required this.status,
    required this.timestamp,
  });

  factory MessageStatus.fromJson(Map<String, dynamic> json) {
    return MessageStatus(
      id: json['id'] as String,
      status: json['status'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }
}
