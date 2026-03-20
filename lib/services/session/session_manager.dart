import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores non-secret session metadata only.
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  static const String _keyUserId = 'user_id';
  static const String _keyUserAddress = 'user_address';
  static const String _keySessionToken = 'backend_session_token';
  static const String _keyExpiryTimestamp = 'expiry_timestamp';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const int _sessionExpiryDays = 30;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    if (await isSessionExpired()) {
      await clearSession();
      debugPrint('[SessionManager] Session expired, cleared old session data');
    }
  }

  Future<void> saveSession({
    required String userId,
    required String userAddress,
    int? expiryDays,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final expiryDate = now.add(
      Duration(days: expiryDays ?? _sessionExpiryDays),
    );

    await Future.wait([
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyUserAddress, userAddress),
      prefs.setInt(_keyExpiryTimestamp, expiryDate.millisecondsSinceEpoch),
      prefs.setInt(_keyLoginTimestamp, now.millisecondsSinceEpoch),
    ]);

    debugPrint('[SessionManager] Session saved for user: $userId');
  }

  Future<void> saveBackendSessionToken(String sessionToken) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionToken, sessionToken);
    debugPrint('[SessionManager] Backend session token saved');
  }

  Future<void> clearBackendSessionToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionToken);
  }

  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString(_keyUserId);
    final userAddress = prefs.getString(_keyUserAddress);
    final sessionToken = prefs.getString(_keySessionToken);
    final expiryTimestamp = prefs.getInt(_keyExpiryTimestamp);
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);

    if (userId == null || userAddress == null) {
      return null;
    }

    return {
      'userId': userId,
      'userAddress': userAddress,
      'sessionToken': sessionToken,
      'expiryTimestamp': expiryTimestamp,
      'loginTimestamp': loginTimestamp,
    };
  }

  Future<bool> isLoggedIn() async {
    final session = await getSession();
    if (session == null) return false;
    return !(await isSessionExpired());
  }

  Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTimestamp = prefs.getInt(_keyExpiryTimestamp);

    if (expiryTimestamp == null) return true;

    return DateTime.now().isAfter(
      DateTime.fromMillisecondsSinceEpoch(expiryTimestamp),
    );
  }

  Future<String?> getUserId() async {
    final session = await getSession();
    return session?['userId'] as String?;
  }

  Future<String?> getUserAddress() async {
    final session = await getSession();
    return session?['userAddress'] as String?;
  }

  Future<String?> getBackendSessionToken() async {
    final session = await getSession();
    return session?['sessionToken'] as String?;
  }

  Future<DateTime?> getLoginDate() async {
    final session = await getSession();
    final loginTimestamp = session?['loginTimestamp'] as int?;
    if (loginTimestamp == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(loginTimestamp);
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserAddress),
      prefs.remove(_keySessionToken),
      prefs.remove(_keyExpiryTimestamp),
      prefs.remove(_keyLoginTimestamp),
    ]);
    debugPrint('[SessionManager] Session cleared');
  }
}
