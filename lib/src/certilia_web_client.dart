// ignore_for_file: avoid_web_libraries_in_flutter
import 'dart:async';
// ignore: deprecated_member_use
import 'package:web/web.dart' as web;

import 'package:flutter/material.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_token.dart';
import 'models/certilia_user.dart';
import 'services/certilia_logger.dart';
import 'services/proxy_auth_service.dart';
import 'services/token_storage_service.dart';

/// Web-specific client for Certilia OAuth authentication.
///
/// Opens a popup window for the auth flow and polls the proxy server for
/// completion (browser cross-origin policies make `postMessage` unreliable
/// with Croatian eID flows — see project history).
///
/// HTTP communication lives in [ProxyAuthService]; token persistence in
/// [TokenStorageService]. This class owns popup window lifecycle and
/// in-memory session state.
class CertiliaWebClient {
  final CertiliaConfig config;
  final String serverUrl;
  final ProxyAuthService _proxy;
  final TokenStorageService _tokenStorage;
  final CertiliaLogger _logger;

  CertiliaToken? _currentToken;

  /// Completes when the constructor's initial token load has finished.
  /// Async-public methods await this so callers don't see "not authenticated"
  /// before storage has been consulted.
  late final Future<void> _ready;

  static const Duration _pollingInterval = Duration(seconds: 2);
  static const Duration _popupCheckInterval = Duration(seconds: 1);
  static const Duration _pollingTimeout = Duration(minutes: 5);
  static const int _popupWidth = 500;
  static const int _popupHeight = 700;

  CertiliaWebClient({
    required this.config,
    required this.serverUrl,
    ProxyAuthService? proxyService,
    TokenStorageService? tokenStorage,
  })  : _logger = CertiliaLogger(
          componentName: 'CertiliaWebClient',
          enableLogging: config.enableLogging,
        ),
        _proxy = proxyService ??
            ProxyAuthService(
              serverUrl: serverUrl,
              logger: CertiliaLogger(
                componentName: 'CertiliaWebClient.proxy',
                enableLogging: config.enableLogging,
              ),
            ),
        _tokenStorage = tokenStorage ?? TokenStorageService() {
    config.validate();
    _ready = _initializeTokens();
  }

  Future<void> _initializeTokens() async {
    _currentToken = await _tokenStorage.loadToken();
    if (_currentToken != null) {
      _logger.log(_currentToken!.isExpired
          ? 'Loaded saved token (expired — caller decides)'
          : 'Loaded saved authentication token');
    }
  }

  /// Runs the full popup + polling OAuth flow. Persists the resulting
  /// tokens, returns the resolved user.
  Future<CertiliaUser> authenticate(BuildContext context) async {
    try {
      await _ready;
      _logger.log('Starting web authentication flow');

      final authData = await _proxy.initialize();
      final polling = await _proxy.startPollingSession(
        state: authData['state'] as String,
        sessionId: authData['session_id'] as String,
      );

      final code = await _openAuthPopupWithPolling(
        authorizationUrl: authData['authorization_url'] as String,
        pollingId: polling['polling_id'] as String,
      );

      if (code == null) {
        throw const CertiliaAuthenticationException(
          message: 'Authentication was cancelled',
        );
      }

      final tokenData = await _proxy.exchange(
        code: code,
        state: authData['state'] as String,
        sessionId: authData['session_id'] as String,
      );

      _currentToken = _tokenFromResponse(tokenData);
      await _tokenStorage.saveToken(_currentToken!);

      final user = tokenData['user'] != null
          ? CertiliaUser.fromJson(tokenData['user'] as Map<String, dynamic>)
          : await _proxy.fetchUserInfo(_currentToken!.accessToken);

      _logger.log('Authentication successful for user: ${user.sub}');
      return user;
    } catch (e) {
      _logger.log('Authentication failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Authentication failed',
        details: e.toString(),
      );
    }
  }

  Future<String?> _openAuthPopupWithPolling({
    required String authorizationUrl,
    required String pollingId,
  }) async {
    final completer = Completer<String?>();

    final left = (web.window.screen.width - _popupWidth) ~/ 2;
    final top = (web.window.screen.height - _popupHeight) ~/ 2;

    _logger.log('Opening auth popup, polling id: $pollingId');
    final popup = web.window.open(
      authorizationUrl,
      'certilia_auth',
      'width=$_popupWidth,height=$_popupHeight,left=$left,top=$top',
    );
    if (popup == null) {
      throw const CertiliaAuthenticationException(
        message: 'Popup blocked. Allow popups for this site and try again.',
      );
    }

    Timer? pollTimer;
    Timer? popupCheckTimer;
    Timer? timeoutTimer;
    var active = true;

    void cleanup() {
      active = false;
      pollTimer?.cancel();
      popupCheckTimer?.cancel();
      timeoutTimer?.cancel();
    }

    void closePopupSoon() {
      Timer(const Duration(milliseconds: 100), () {
        try {
          popup.close();
        } catch (_) {}
      });
    }

    timeoutTimer = Timer(_pollingTimeout, () {
      if (completer.isCompleted) return;
      _logger.log('Polling timeout reached');
      cleanup();
      completer.complete(null);
      closePopupSoon();
    });

    pollTimer = Timer.periodic(_pollingInterval, (_) async {
      if (!active) return;
      try {
        final data = await _proxy.pollStatus(pollingId);
        if (data == null) {
          // Session expired or not found.
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          return;
        }
        final status = data['status'];
        if (status == 'completed' && data['result'] != null) {
          final code = (data['result'] as Map<String, dynamic>)['code'];
          _logger.log('Auth completed via polling');
          cleanup();
          if (!completer.isCompleted) completer.complete(code as String?);
          closePopupSoon();
        } else if (status == 'error') {
          _logger.log('Server reported auth error: ${data['error']}');
          cleanup();
          if (!completer.isCompleted) completer.complete(null);
          closePopupSoon();
        }
      } catch (e) {
        _logger.log('Polling error: $e');
      }
    });

    popupCheckTimer = Timer.periodic(_popupCheckInterval, (timer) {
      if (popup.closed) {
        timer.cancel();
        // Give polling one more window — server callback may still be in flight.
        Timer(const Duration(seconds: 3), () {
          if (!completer.isCompleted && active) {
            _logger.log('Popup closed without polling result');
            cleanup();
            completer.complete(null);
          }
        });
      }
    });

    return completer.future;
  }

  bool get isAuthenticated =>
      _currentToken != null && !_currentToken!.isExpired;

  Future<bool> checkAuthenticationStatus() async {
    await _ready;
    return isAuthenticated;
  }

  Future<CertiliaUser?> getCurrentUser() async {
    try {
      await _ready;
      if (_currentToken == null) return null;

      if (_currentToken!.isExpired) {
        if (_currentToken!.refreshToken == null) return null;
        await refreshToken();
      }

      return await _proxy.fetchUserInfo(_currentToken!.accessToken);
    } catch (e) {
      _logger.log('Failed to get current user: $e');
      return null;
    }
  }

  Future<void> refreshToken() async {
    if (_currentToken?.refreshToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No refresh token available',
      );
    }
    try {
      _logger.log('Refreshing token');
      final tokenData = await _proxy.refresh(
        accessToken: _currentToken!.accessToken,
        refreshToken: _currentToken!.refreshToken!,
      );
      _currentToken = _tokenFromResponse(
        tokenData,
        fallbackRefreshToken: _currentToken!.refreshToken,
      );
      await _tokenStorage.saveToken(_currentToken!);
      _logger.log('Token refreshed successfully');
    } catch (e) {
      _logger.log('Token refresh failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Failed to refresh token',
        details: e.toString(),
      );
    }
  }

  Future<void> logout() async {
    await _ready;
    _logger.log('Logging out user');
    _currentToken = null;
    await _tokenStorage.deleteToken();
  }

  /// Returns extended user info. Auto-refreshes once on 401, auto-logs-out
  /// if refresh fails.
  Future<CertiliaExtendedInfo?> getExtendedUserInfo() async {
    await _ready;
    if (_currentToken == null || _currentToken!.isExpired) {
      _logger.log('No valid token for extended info');
      return null;
    }

    final info = await _proxy.fetchExtendedInfo(_currentToken!.accessToken);
    if (info != null) return info;

    // 401/502 — try to refresh once.
    if (_currentToken!.refreshToken == null) {
      await logout();
      return null;
    }
    try {
      await refreshToken();
      return await _proxy.fetchExtendedInfo(_currentToken!.accessToken);
    } catch (e) {
      _logger.log('Refresh failed, clearing authentication: $e');
      await logout();
      return null;
    }
  }

  String? get currentAccessToken => _currentToken?.accessToken;
  String? get currentRefreshToken => _currentToken?.refreshToken;
  String? get currentIdToken => _currentToken?.idToken;
  DateTime? get tokenExpiry => _currentToken?.expiresAt;

  void dispose() => _proxy.close();

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
}

/// Alias for platform client
typedef CertiliaPlatformClient = CertiliaWebClient;
