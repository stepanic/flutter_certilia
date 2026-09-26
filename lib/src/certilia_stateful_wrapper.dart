import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'certilia_browser_client.dart';
import 'certilia_native_client.dart';
import 'certilia_webview_client.dart';
import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'refresh_errors.dart';
import 'services/certilia_logger.dart';
import 'services/token_storage_service.dart';

/// Stateful wrapper around a stateless [CertiliaNativeClient]:
/// [CertiliaBrowserClient] when [CertiliaConfig.callbackUrl] is set,
/// otherwise [CertiliaWebViewClient].
///
/// Stores the token and the user in secure storage, refreshes an expired
/// token, and keeps the current user in memory. Used on mobile and desktop;
/// on web, `CertiliaWebClient` keeps this state itself.
class CertiliaStatefulWrapper {
  final CertiliaNativeClient _client;
  final TokenStorageService _tokenStorage;
  final FlutterSecureStorage _userStorage;
  final CertiliaLogger _logger;

  CertiliaToken? _currentToken;
  CertiliaUser? _currentUser;

  /// Completes when the constructor has loaded the saved token and user.
  /// The public async methods await it, so a new instance does not report
  /// "not authenticated" before storage has been read.
  late final Future<void> _ready;

  static const String _userStorageKey = 'certilia_user';
  static const FlutterSecureStorage _sharedStorage = FlutterSecureStorage();

  CertiliaStatefulWrapper({
    required CertiliaConfig config,
    required String serverUrl,
    FlutterSecureStorage? storage,
    TokenStorageService? tokenStorage,
    CertiliaNativeClient? client,
  })  : _client = client ??
            (config.callbackUrl != null
                ? CertiliaBrowserClient(config: config, serverUrl: serverUrl)
                : CertiliaWebViewClient(config: config, serverUrl: serverUrl)),
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
    _logger.log('Auth data received');

    _currentToken = _tokenFromResponse(authData);
    await _tokenStorage.saveToken(_currentToken!);

    if (authData['user'] != null) {
      _currentUser =
          CertiliaUser.fromJson(authData['user'] as Map<String, dynamic>);
    } else {
      _currentUser = await _client.getUserInfo(
        _currentToken!.accessToken,
        idToken: _currentToken!.idToken,
      );
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
      try {
        await refreshToken();
      } on CertiliaException catch (e) {
        // Certilia currently refuses refresh for portal clients, so in direct
        // mode every session ends here when the access token expires. End it
        // cleanly instead of throwing at the caller. A timeout or outage
        // keeps the session, so a later call can still refresh it.
        if (!refreshWasRefused(e)) rethrow;
        _logger.log('Refresh refused, logging out: $e');
        await logout();
        return null;
      }
    }

    if (_currentUser != null) return _currentUser;

    _currentUser = await _client.getUserInfo(
        _currentToken!.accessToken,
        idToken: _currentToken!.idToken,
      );
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
      idToken: _currentToken!.idToken,
    );
    _currentToken = _tokenFromResponse(
      tokenData,
      fallbackRefreshToken: _currentToken!.refreshToken,
      fallbackIdToken: _currentToken!.idToken,
    );
    await _tokenStorage.saveToken(_currentToken!);
    _logger.log('Token saved to secure storage');
  }

  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    await _ready;
    if (_currentToken == null || _currentToken!.isExpired) return null;

    try {
      return await _client.getExtendedUserInfo(
        _currentToken!.accessToken,
        idToken: _currentToken!.idToken,
      );
    } catch (e) {
      // Refresh once on 401/expired errors, then retry.
      final msg = e.toString();
      if (msg.contains('401') || msg.contains('expired')) {
        if (_currentToken!.refreshToken != null) {
          try {
            await refreshToken();
          } catch (e) {
            if (!refreshWasRefused(e)) rethrow;
            await logout();
            return null;
          }
          return await _client.getExtendedUserInfo(
            _currentToken!.accessToken,
            idToken: _currentToken!.idToken,
          );
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
      // The saved user is only a cache: without it, the next start fetches
      // the user again.
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
    String? fallbackIdToken,
  }) {
    final expiresIn = data['expiresIn'];
    return CertiliaToken(
      accessToken: data['accessToken'] as String,
      refreshToken:
          (data['refreshToken'] as String?) ?? fallbackRefreshToken,
      idToken: (data['idToken'] as String?) ?? fallbackIdToken,
      expiresAt: expiresIn != null
          ? DateTime.now().add(Duration(seconds: expiresIn as int))
          : null,
      tokenType: (data['tokenType'] as String?) ?? 'Bearer',
    );
  }

  // Static helpers that read the saved token and user without an instance.

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
