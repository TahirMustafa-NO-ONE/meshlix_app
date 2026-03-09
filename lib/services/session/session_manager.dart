import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage user session persistence using SharedPreferences
///
/// Handles:
/// - Saving session data (auth token, user ID, expiry)
/// - Retrieving session data
/// - Validating session expiry
/// - Clearing session on logout
class SessionManager {
  SessionManager._();
  static final SessionManager instance = SessionManager._();

  // SharedPreferences keys
  static const String _keyAuthToken = 'auth_token';
  static const String _keyUserId = 'user_id';
  static const String _keyUserAddress = 'user_address';
  static const String _keyExpiryTimestamp = 'expiry_timestamp';
  static const String _keyLoginTimestamp = 'login_timestamp';

  // Session configuration
  static const int _sessionExpiryDays = 30; // Default 30-day session expiry

  bool _isInitialized = false;

  /// Initialize the session manager
  /// Call this once during app startup
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // Check if session is expired and clear if needed
    if (await isSessionExpired()) {
      await clearSession();
      debugPrint('[SessionManager] Session expired, cleared old session data');
    } else {
      final session = await getSession();
      if (session != null) {
        debugPrint(
          '[SessionManager] Valid session found for user: ${session['userId']}',
        );
      }
    }
  }

  /// Save user session data
  ///
  /// [authToken] - The authentication token (private key or session token)
  /// [userId] - Unique user identifier (email, username, or address)
  /// [userAddress] - User's public wallet address
  /// [expiryDays] - Optional custom expiry duration (defaults to 30 days)
  Future<void> saveSession({
    required String authToken,
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
      prefs.setString(_keyAuthToken, authToken),
      prefs.setString(_keyUserId, userId),
      prefs.setString(_keyUserAddress, userAddress),
      prefs.setInt(_keyExpiryTimestamp, expiryDate.millisecondsSinceEpoch),
      prefs.setInt(_keyLoginTimestamp, now.millisecondsSinceEpoch),
    ]);

    debugPrint('[SessionManager] Session saved for user: $userId');
    debugPrint('[SessionManager] Session expires: ${expiryDate.toLocal()}');
  }

  /// Retrieve stored session data
  ///
  /// Returns a Map with session data or null if no session exists
  /// Map contains: authToken, userId, userAddress, expiryTimestamp, loginTimestamp
  Future<Map<String, dynamic>?> getSession() async {
    final prefs = await SharedPreferences.getInstance();

    final authToken = prefs.getString(_keyAuthToken);
    final userId = prefs.getString(_keyUserId);
    final userAddress = prefs.getString(_keyUserAddress);
    final expiryTimestamp = prefs.getInt(_keyExpiryTimestamp);
    final loginTimestamp = prefs.getInt(_keyLoginTimestamp);

    // If any required field is missing, session is invalid
    if (authToken == null || userId == null || userAddress == null) {
      return null;
    }

    return {
      'authToken': authToken,
      'userId': userId,
      'userAddress': userAddress,
      'expiryTimestamp': expiryTimestamp,
      'loginTimestamp': loginTimestamp,
    };
  }

  /// Check if a valid session exists and is not expired
  Future<bool> isLoggedIn() async {
    final session = await getSession();
    if (session == null) return false;

    return !(await isSessionExpired());
  }

  /// Check if the current session has expired
  Future<bool> isSessionExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final expiryTimestamp = prefs.getInt(_keyExpiryTimestamp);

    if (expiryTimestamp == null) return true;

    final expiryDate = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
    final isExpired = DateTime.now().isAfter(expiryDate);

    if (isExpired) {
      debugPrint(
        '[SessionManager] Session expired at: ${expiryDate.toLocal()}',
      );
    }

    return isExpired;
  }

  /// Get the stored auth token
  Future<String?> getAuthToken() async {
    final session = await getSession();
    return session?['authToken'];
  }

  /// Get the stored user ID
  Future<String?> getUserId() async {
    final session = await getSession();
    return session?['userId'];
  }

  /// Get the stored user address
  Future<String?> getUserAddress() async {
    final session = await getSession();
    return session?['userAddress'];
  }

  /// Get session expiry date
  Future<DateTime?> getExpiryDate() async {
    final session = await getSession();
    final expiryTimestamp = session?['expiryTimestamp'];

    if (expiryTimestamp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(expiryTimestamp as int);
  }

  /// Get session login date
  Future<DateTime?> getLoginDate() async {
    final session = await getSession();
    final loginTimestamp = session?['loginTimestamp'];

    if (loginTimestamp == null) return null;

    return DateTime.fromMillisecondsSinceEpoch(loginTimestamp as int);
  }

  /// Clear all session data (call on logout)
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();

    await Future.wait([
      prefs.remove(_keyAuthToken),
      prefs.remove(_keyUserId),
      prefs.remove(_keyUserAddress),
      prefs.remove(_keyExpiryTimestamp),
      prefs.remove(_keyLoginTimestamp),
    ]);

    debugPrint('[SessionManager] Session cleared');
  }

  /// Extend the current session expiry by the specified number of days
  /// Useful for "remember me" or extending active sessions
  Future<void> extendSession({int additionalDays = 30}) async {
    final session = await getSession();
    if (session == null) {
      debugPrint('[SessionManager] Cannot extend session - no active session');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final newExpiryDate = DateTime.now().add(Duration(days: additionalDays));

    await prefs.setInt(
      _keyExpiryTimestamp,
      newExpiryDate.millisecondsSinceEpoch,
    );

    debugPrint(
      '[SessionManager] Session extended until: ${newExpiryDate.toLocal()}',
    );
  }
}
