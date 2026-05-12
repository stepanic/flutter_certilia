import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'certilia_webview_client.dart';
import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'services/certilia_logger.dart';
import 'services/token_storage_service.dart';

/// Stateful wrapper around the stateless [CertiliaWebViewClient].
///
/// Manages token + user persistence, refresh-on-expiry, and cached user
/// state. Used on mobile/desktop targets; the web target's
/// `CertiliaWebClient` is already stateful by necessity (popup polling).
class CertiliaStatefulWrapper {
  final CertiliaWebViewClient _client;
  final TokenStorageService _tokenStorage;
  final FlutterSecureStorage _userStorage;
  final CertiliaLogger _logger;

  CertiliaToken? _currentToken;
  CertiliaUser? _currentUser;

  /// Completes when the constructor's initial token + user load has finished.
  /// Async-public methods await this so callers don't see a fresh-instance
  /// "not authenticated" before storage has been consulted.
  late final Future<void> _ready;

  static const String _userStorageKey = 'certilia_user';
  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();

  CertiliaStatefulWrapper({
    required CertiliaConfig config,
    required String serverUrl,
    FlutterSecureStorage? storage,
    TokenStorageService? tokenStorage,
    CertiliaWebViewClient? client,
  })  : _client = client ??
            CertiliaWebViewClient(
              config: config,
              serverUrl: serverUrl,
            ),
        _tokenStorage =
            tokenStorage ?? TokenStorageService(storage: storage),
        _userStorage = storage ?? const FlutterSecureStorage(),
        _logger = CertiliaLogger(
          componentName: 'CertiliaStatefulWrapper',
          enableLogging: config.enableLogging,
        ) {
    _ready = _initializeState();
  }

  Future<void> _initializeState() async {
    _currentToken = await _tokenStorage.loadToken();
    _currentUser = await _loadUser();
  }

  Future<CertiliaUser> authenticate(BuildContext context) async {
    await _ready;
    if (!context.mounted) {
      throw const CertiliaAuthenticationException(
        message: 'Context no longer mounted',
      );
    }
    _logger.log('Starting authentication...');
    final authData = await _client.authenticate(context);
    _logger.log('Auth data received from WebView');

    _currentToken = _tokenFromResponse(authData);
    await _tokenStorage.saveToken(_currentToken!);

    if (authData['user'] != null) {
      _currentUser =
          CertiliaUser.fromJson(authData['user'] as Map<String, dynamic>);
    } else {
      _currentUser = await _client.getUserInfo(_currentToken!.accessToken);
    }
    if (_currentUser != null) {
      await _saveUser(_currentUser!);
    }
    return _currentUser!;
  }

  bool get isAuthenticated =>
      _currentToken != null && !_currentToken!.isExpired;

  Future<bool> checkAuthenticationStatus() async {
    await _ready;
    return isAuthenticated;
  }

  Future<CertiliaUser?> getCurrentUser() async {
    await _ready;

    if (_currentToken == null) return null;

    if (_currentToken!.isExpired) {
      if (_currentToken!.refreshToken == null) return null;
      await refreshToken();
    }

    if (_currentUser != null) return _currentUser;

    _currentUser = await _client.getUserInfo(_currentToken!.accessToken);
    if (_currentUser != null) {
      await _saveUser(_currentUser!);
    }
    return _currentUser;
  }

  Future<void> refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No refresh token available',
      );
    }
    _logger.log('Starting token refresh...');
    final tokenData = await _client.refreshToken(
      accessToken: _currentToken!.accessToken,
      refreshToken: _currentToken!.refreshToken!,
    );
    _currentToken = _tokenFromResponse(
      tokenData,
      fallbackRefreshToken: _currentToken!.refreshToken,
    );
    await _tokenStorage.saveToken(_currentToken!);
    _logger.log('Token saved to secure storage');
  }

  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    await _ready;
    if (_currentToken == null || _currentToken!.isExpired) return null;

    try {
      return await _client.getExtendedUserInfo(_currentToken!.accessToken);
    } catch (e) {
      // Refresh once on 401/expired errors, then retry.
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('expired')) {
        if (_currentToken!.refreshToken != null) {
          try {
            await refreshToken();
            return await _client
                .getExtendedUserInfo(_currentToken!.accessToken);
          } catch (_) {
            await logout();
            return null;
          }
        }
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await _ready;
    _currentToken = null;
    _currentUser = null;
    await _tokenStorage.deleteToken();
    await _userStorage.delete(key: _userStorageKey);
  }

  Future<void> _saveUser(CertiliaUser user) async {
    try {
      await _userStorage.write(
        key: _userStorageKey,
        value: jsonEncode(user.toJson()),
      );
    } catch (_) {
      // Silent — best-effort cache.
    }
  }

  Future<CertiliaUser?> _loadUser() async {
    try {
      final userJson = await _userStorage.read(key: _userStorageKey);
      if (userJson == null) return null;
      return CertiliaUser.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  String? get currentAccessToken => _currentToken?.accessToken;
  String? get currentRefreshToken => _currentToken?.refreshToken;
  String? get currentIdToken => _currentToken?.idToken;
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  void dispose() => _client.dispose();

  CertiliaToken _tokenFromResponse(
    Map<String, dynamic> data, {
    String? fallbackRefreshToken,
  }) {
    final expiresIn = data['expiresIn'];
    return CertiliaToken(
      accessToken: data['accessToken'] as String,
      refreshToken:
          (data['refreshToken'] as String?) ?? fallbackRefreshToken,
      idToken: data['idToken'] as String?,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn as int))
          : null,
      tokenType: (data['tokenType'] as String?) ?? 'Bearer',
    );
  }

  // ===== Static helpers for reading stored tokens without an instance =====

  static final TokenStorageService _staticTokenStorage =
      TokenStorageService();

  static Future<String?> getStoredAccessToken() async {
    final token = await _staticTokenStorage.loadToken();
    return (token != null && !token.isExpired) ? token.accessToken : null;
  }

  static Future<String?> getStoredRefreshToken() async {
    final token = await _staticTokenStorage.loadToken();
    return token?.refreshToken;
  }

  static Future<DateTime?> getStoredTokenExpiry() async {
    final token = await _staticTokenStorage.loadToken();
    return token?.expiresAt;
  }

  static Future<CertiliaUser?> getStoredUser() async {
    try {
      final userJson = await _sharedStorage.read(key: _userStorageKey);
      if (userJson == null) return null;
      return CertiliaUser.fromJson(
        jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  static Future<bool> hasValidStoredToken() async =>
      (await getStoredAccessToken()) != null;

  static Future<void> clearStoredData() async {
    await _staticTokenStorage.deleteToken();
    try {
      await _sharedStorage.delete(key: _userStorageKey);
    } catch (_) {}
  }
}
