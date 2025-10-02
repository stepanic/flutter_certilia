import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'certilia_webview_client.dart';
import 'models/certilia_config.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'models/certilia_extended_info.dart';
import 'exceptions/certilia_exception.dart';

/// Stateful wrapper around the stateless CertiliaWebViewClient
/// This wrapper manages token storage and state management
class CertiliaStatefulWrapper {
  final CertiliaWebViewClient _client;
  final FlutterSecureStorage _storage;

  // In-memory state
  CertiliaToken? _currentToken;
  CertiliaUser? _currentUser;

  // Storage keys
  static const String _tokenStorageKey = 'certilia_token';
  static const String _userStorageKey = 'certilia_user';

  // Shared storage instance for static methods
  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();

  CertiliaStatefulWrapper({
    required CertiliaConfig config,
    String? serverUrl,
    FlutterSecureStorage? storage,
  }) : _client = CertiliaWebViewClient(
          config: config,
          serverUrl: serverUrl,
        ),
        _storage = storage ?? const FlutterSecureStorage() {
    // Load saved state on initialization
    _initializeState();
  }

  /// Initialize state from storage
  Future<void> _initializeState() async {
    try {
      await _loadToken();
      await _loadUser();
    } catch (e) {
      // Silent fail - continue without saved state
    }
  }

  /// Authenticate using WebView and manage state
  Future<CertiliaUser> authenticate(BuildContext context) async {
    print('🔐 [CertiliaStatefulWrapper] Starting authentication...');
    // Call stateless authenticate
    final authData = await _client.authenticate(context);
    print('📦 [CertiliaStatefulWrapper] Auth data received from WebView');

    // Create token object
    _currentToken = CertiliaToken(
      accessToken: authData['accessToken'],
      refreshToken: authData['refreshToken'],
      idToken: authData['idToken'],
      expiresAt: authData['expiresIn'] != null
          ? DateTime.now().add(Duration(seconds: authData['expiresIn']))
          : null,
      tokenType: authData['tokenType'] ?? 'Bearer',
    );

    // Save token
    await _saveToken(_currentToken!);

    // Extract or fetch user
    if (authData['user'] != null) {
      _currentUser = CertiliaUser.fromJson(authData['user']);
    } else {
      _currentUser = await _client.getUserInfo(_currentToken!.accessToken);
    }

    // Save user
    if (_currentUser != null) {
      await _saveUser(_currentUser!);
    }

    return _currentUser!;
  }

  /// Check if authenticated
  bool get isAuthenticated {
    return _currentToken != null && !_currentToken!.isExpired;
  }

  /// Check authentication status (with storage load)
  Future<bool> checkAuthenticationStatus() async {
    if (_currentToken == null) {
      await _loadToken();
    }
    return isAuthenticated;
  }

  /// Get current user
  Future<CertiliaUser?> getCurrentUser() async {
    if (_currentToken == null) {
      await _loadToken();
    }
    if (_currentUser == null) {
      await _loadUser();
    }

    if (_currentToken == null) {
      return null;
    }

    // Check if token is expired
    if (_currentToken!.isExpired) {
      // Try to refresh
      if (_currentToken!.refreshToken != null) {
        await refreshToken();
      } else {
        return null;
      }
    }

    // Return cached user or fetch
    if (_currentUser != null) {
      return _currentUser;
    }

    _currentUser = await _client.getUserInfo(_currentToken!.accessToken);
    if (_currentUser != null) {
      await _saveUser(_currentUser!);
    }

    return _currentUser;
  }

  /// Refresh token
  Future<void> refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No refresh token available',
      );
    }

    print('🔄 [CertiliaStatefulWrapper] Starting token refresh...');
    print('📝 Old token expiry: ${_currentToken?.expiresAt}');

    final tokenData = await _client.refreshToken(
      accessToken: _currentToken!.accessToken,
      refreshToken: _currentToken!.refreshToken!,
    );

    print('📦 Token data received: expiresIn=${tokenData['expiresIn']} seconds');

    // Update token
    _currentToken = CertiliaToken(
      accessToken: tokenData['accessToken'],
      refreshToken: tokenData['refreshToken'] ?? _currentToken!.refreshToken,
      idToken: tokenData['idToken'],
      expiresAt: tokenData['expiresIn'] != null
          ? DateTime.now().add(Duration(seconds: tokenData['expiresIn']))
          : null,
      tokenType: tokenData['tokenType'] ?? 'Bearer',
    );

    print('✨ New token created with expiry: ${_currentToken!.expiresAt}');
    print('🔑 New access token (first 20): ${_currentToken!.accessToken.substring(0, 20)}...');

    // Save updated token
    await _saveToken(_currentToken!);
    print('💾 Token saved to secure storage');
  }

  /// Get extended user info
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    if (_currentToken == null) {
      await _loadToken();
    }

    if (_currentToken == null || _currentToken!.isExpired) {
      return null;
    }

    try {
      return await _client.getExtendedUserInfo(_currentToken!.accessToken);
    } catch (e) {
      // Try refresh on auth error
      if (e.toString().contains('401') || e.toString().contains('expired')) {
        if (_currentToken!.refreshToken != null) {
          try {
            await refreshToken();
            return await _client.getExtendedUserInfo(_currentToken!.accessToken);
          } catch (refreshError) {
            await logout();
            return null;
          }
        }
      }
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    // Clear memory state
    _currentToken = null;
    _currentUser = null;

    // Clear storage
    await _storage.delete(key: _tokenStorageKey);
    await _storage.delete(key: _userStorageKey);
  }

  // Storage helpers
  Future<void> _saveToken(CertiliaToken token) async {
    try {
      final tokenJson = jsonEncode(token.toJson());
      await _storage.write(key: _tokenStorageKey, value: tokenJson);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadToken() async {
    try {
      final tokenJson = await _storage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        _currentToken = CertiliaToken.fromJson(tokenData);
      }
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _saveUser(CertiliaUser user) async {
    try {
      final userJson = jsonEncode(user.toJson());
      await _storage.write(key: _userStorageKey, value: userJson);
    } catch (e) {
      // Silent fail
    }
  }

  Future<void> _loadUser() async {
    try {
      final userJson = await _storage.read(key: _userStorageKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = CertiliaUser.fromJson(userData);
      }
    } catch (e) {
      // Silent fail
    }
  }

  // Getters for tokens
  String? get currentAccessToken => _currentToken?.accessToken;
  String? get currentRefreshToken => _currentToken?.refreshToken;
  String? get currentIdToken => _currentToken?.idToken;
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  /// Dispose
  void dispose() {
    _client.dispose();
  }

  // ===== STATIC METHODS FOR ACCESSING STORED TOKENS =====

  /// Get the last stored access token (static method)
  static Future<String?> getStoredAccessToken() async {
    try {
      final tokenJson = await _sharedStorage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        final token = CertiliaToken.fromJson(tokenData);
        // Check if token is expired
        if (!token.isExpired) {
          return token.accessToken;
        }
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Get the last stored refresh token (static method)
  static Future<String?> getStoredRefreshToken() async {
    try {
      final tokenJson = await _sharedStorage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        final token = CertiliaToken.fromJson(tokenData);
        return token.refreshToken;
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Get the stored token expiry time (static method)
  static Future<DateTime?> getStoredTokenExpiry() async {
    try {
      final tokenJson = await _sharedStorage.read(key: _tokenStorageKey);
      if (tokenJson != null) {
        final tokenData = jsonDecode(tokenJson) as Map<String, dynamic>;
        final token = CertiliaToken.fromJson(tokenData);
        return token.expiresAt;
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Get the last stored user (static method)
  static Future<CertiliaUser?> getStoredUser() async {
    try {
      final userJson = await _sharedStorage.read(key: _userStorageKey);
      if (userJson != null) {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        return CertiliaUser.fromJson(userData);
      }
    } catch (e) {
      // Silent fail
    }
    return null;
  }

  /// Check if there's a valid stored token (static method)
  static Future<bool> hasValidStoredToken() async {
    final token = await getStoredAccessToken();
    return token != null;
  }

  /// Clear all stored data (static method)
  static Future<void> clearStoredData() async {
    try {
      await _sharedStorage.delete(key: _tokenStorageKey);
      await _sharedStorage.delete(key: _userStorageKey);
    } catch (e) {
      // Silent fail
    }
  }
}