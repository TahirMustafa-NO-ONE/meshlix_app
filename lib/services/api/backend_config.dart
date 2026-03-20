import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class BackendConfig {
  BackendConfig._();

  static String get httpBaseUrl {
    final fallback = kIsWeb
        ? 'http://localhost:3000'
        : 'http://192.168.1.2:3000';
    return _stripTrailingSlash(dotenv.env['BACKEND_URL'] ?? fallback);
  }

  static String get wsBaseUrl {
    final explicit = dotenv.env['BACKEND_WS_URL'];
    if (explicit != null && explicit.isNotEmpty) {
      return _stripTrailingSlash(explicit);
    }

    if (httpBaseUrl.startsWith('https://')) {
      return httpBaseUrl.replaceFirst('https://', 'wss://');
    }

    if (httpBaseUrl.startsWith('http://')) {
      return httpBaseUrl.replaceFirst('http://', 'ws://');
    }

    throw Exception('Unsupported backend URL scheme: $httpBaseUrl');
  }

  static String _stripTrailingSlash(String value) {
    if (value.endsWith('/')) {
      return value.substring(0, value.length - 1);
    }
    return value;
  }
}
