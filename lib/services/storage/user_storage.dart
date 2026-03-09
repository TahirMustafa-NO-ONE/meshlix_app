import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/auth_user.dart';

/// Service to manage user login history and storage
class UserStorage {
  UserStorage._();
  static final UserStorage instance = UserStorage._();

  static const String _usersKey = 'logged_in_users';
  static const String _currentUserKey = 'current_user_address';

  List<AuthUser> _cachedUsers = [];
  bool _isInitialized = false;

  /// Initialize the storage service
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadUsers();
    _isInitialized = true;
    debugPrint('[UserStorage] Initialized with ${_cachedUsers.length} users');
  }

  /// Get all users who have logged in
  Future<List<AuthUser>> getAllUsers() async {
    if (!_isInitialized) await initialize();
    return List.unmodifiable(_cachedUsers);
  }

  /// Save a user to storage (adds or updates)
  Future<void> saveUser(AuthUser user) async {
    if (!_isInitialized) await initialize();

    // Remove existing user with same address
    _cachedUsers.removeWhere((u) => u.publicAddress == user.publicAddress);

    // Add user to the beginning of the list
    _cachedUsers.insert(0, user);

    // Keep only the last 50 users to avoid storage bloat
    if (_cachedUsers.length > 50) {
      _cachedUsers = _cachedUsers.sublist(0, 50);
    }

    await _persistUsers();
    debugPrint('[UserStorage] Saved user: ${user.publicAddress}');
  }

  /// Remove a user from storage
  Future<void> removeUser(String publicAddress) async {
    if (!_isInitialized) await initialize();

    _cachedUsers.removeWhere((u) => u.publicAddress == publicAddress);
    await _persistUsers();
    debugPrint('[UserStorage] Removed user: $publicAddress');
  }

  /// Clear all stored users
  Future<void> clearAllUsers() async {
    if (!_isInitialized) await initialize();

    _cachedUsers.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usersKey);
    await prefs.remove(_currentUserKey);
    debugPrint('[UserStorage] Cleared all users');
  }

  /// Load users from SharedPreferences
  Future<void> _loadUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = prefs.getString(_usersKey);

      if (usersJson != null && usersJson.isNotEmpty) {
        final List<dynamic> usersList = jsonDecode(usersJson);
        _cachedUsers = usersList
            .map((json) => _userFromJson(json as Map<String, dynamic>))
            .where((user) => user != null)
            .cast<AuthUser>()
            .toList();
      }
    } catch (e) {
      debugPrint('[UserStorage] Error loading users: $e');
      _cachedUsers = [];
    }
  }

  /// Persist users to SharedPreferences
  Future<void> _persistUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final usersJson = jsonEncode(
        _cachedUsers.map((user) => _userToJson(user)).toList(),
      );
      await prefs.setString(_usersKey, usersJson);
    } catch (e) {
      debugPrint('[UserStorage] Error persisting users: $e');
    }
  }

  /// Convert AuthUser to JSON
  Map<String, dynamic> _userToJson(AuthUser user) {
    return {
      'email': user.email,
      'name': user.name,
      'profileImage': user.profileImage,
      'publicAddress': user.publicAddress,
      'username': user.username,
      'provider': user.provider.name,
      'verifier': user.verifier,
      'verifierId': user.verifierId,
      'typeOfLogin': user.typeOfLogin,
      'aggregateVerifier': user.aggregateVerifier,
    };
  }

  /// Convert JSON to AuthUser
  AuthUser? _userFromJson(Map<String, dynamic> json) {
    try {
      return AuthUser(
        email: json['email'] as String?,
        name: json['name'] as String?,
        profileImage: json['profileImage'] as String?,
        publicAddress: json['publicAddress'] as String,
        username: json['username'] as String,
        provider: _parseAuthProvider(json['provider'] as String),
        verifier: json['verifier'] as String?,
        verifierId: json['verifierId'] as String?,
        typeOfLogin: json['typeOfLogin'] as String?,
        aggregateVerifier: json['aggregateVerifier'] as String?,
      );
    } catch (e) {
      debugPrint('[UserStorage] Error parsing user from JSON: $e');
      return null;
    }
  }

  /// Parse AuthProvider from string
  AuthProvider _parseAuthProvider(String provider) {
    switch (provider) {
      case 'google':
        return AuthProvider.google;
      case 'emailOTP':
        return AuthProvider.emailOTP;
      case 'wallet':
        return AuthProvider.wallet;
      case 'externalWallet':
        return AuthProvider.externalWallet;
      default:
        return AuthProvider.unknown;
    }
  }
}
