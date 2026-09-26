import 'package:flutter/widgets.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_user.dart';
import 'services/certilia_logger.dart';
import 'services/proxy_auth_service.dart';

/// OAuth flow shared by the mobile/desktop clients.
///
/// The proxy builds the authorization URL and exchanges the code, because
/// Certilia only issues confidential clients (the token endpoint rejects a
/// request without the client secret). Subclasses decide how the user
/// reaches Certilia's login page and how the redirect comes back to the
/// app: [CertiliaWebViewClient] watches an in-app WebView for the proxy's
/// callback URL, [CertiliaBrowserClient] lets the system browser return a
/// custom-scheme or App Link redirect.
///
/// Stateless: callers (typically [CertiliaStatefulWrapper]) store tokens.
abstract class CertiliaNativeClient {
  final CertiliaConfig config;
  final String serverUrl;
  final ProxyAuthService proxy;
  final CertiliaLogger logger;

  CertiliaNativeClient({
    required this.config,
    required this.serverUrl,
    required String componentName,
    ProxyAuthService? proxyService,
  })  : logger = CertiliaLogger(
          componentName: componentName,
          enableLogging: config.enableLogging,
        ),
        proxy = proxyService ??
            ProxyAuthService(
              serverUrl: serverUrl,
              logger: CertiliaLogger(
                componentName: '$componentName.proxy',
                enableLogging: config.enableLogging,
              ),
            ) {
    config.validate();
  }

  /// The redirect URI sent to `/api/auth/initialize`. Certilia sends the
  /// browser there after login.
  String get redirectUri;

  /// Shows Certilia's login page for [authorizationUrl] and returns the
  /// callback URL Certilia redirected to, or `null` if the user cancelled.
  Future<Uri?> obtainCallback(BuildContext context, String authorizationUrl);

  /// Runs the full OAuth flow. Returns the raw token bundle from
  /// `/api/auth/exchange` (`accessToken`, `refreshToken`, `idToken`,
  /// `expiresIn`, `tokenType`, `user`).
  Future<Map<String, dynamic>> authenticate(BuildContext context) async {
    try {
      logger.log('Starting authentication, redirect URI: $redirectUri');
      final authData = await proxy.initialize(redirectUri: redirectUri);
      final state = authData['state'] as String;

      if (!context.mounted) {
        throw const CertiliaAuthenticationException(
          message: 'Context no longer mounted',
        );
      }

      final callback = await obtainCallback(
        context,
        authData['authorization_url'] as String,
      );
      final code = codeFromCallback(callback, expectedState: state);

      final tokenData = await proxy.exchange(
        code: code,
        state: state,
        sessionId: authData['session_id'] as String,
      );

      logger.log('Authentication successful');
      return {
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'],
        'idToken': tokenData['idToken'],
        'expiresIn': tokenData['expiresIn'],
        'tokenType': tokenData['tokenType'] ?? 'Bearer',
        'user': tokenData['user'],
      };
    } catch (e) {
      logger.log('Authentication failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Authentication failed',
        details: e.toString(),
      );
    }
  }

  /// Refreshes tokens. Returns the new token bundle.
  Future<Map<String, dynamic>> refreshToken({
    required String accessToken,
    required String refreshToken,
  }) async {
    try {
      logger.log('Refreshing token');
      final tokenData = await proxy.refresh(
        accessToken: accessToken,
        refreshToken: refreshToken,
      );
      logger.log('Token refreshed successfully');
      return {
        'accessToken': tokenData['accessToken'],
        'refreshToken': tokenData['refreshToken'] ?? refreshToken,
        'idToken': tokenData['idToken'],
        'expiresIn': tokenData['expiresIn'],
        'tokenType': tokenData['tokenType'] ?? 'Bearer',
      };
    } catch (e) {
      logger.log('Token refresh failed: $e');
      if (e is CertiliaException) rethrow;
      throw CertiliaAuthenticationException(
        message: 'Failed to refresh token',
        details: e.toString(),
      );
    }
  }

  /// Fetches basic user info using the supplied access token.
  /// Returns null on failure rather than throwing — callers expect this.
  Future<CertiliaUser?> getUserInfo(String accessToken) async {
    try {
      return await proxy.fetchUserInfo(accessToken);
    } catch (e) {
      logger.log('Failed to get user info: $e');
      return null;
    }
  }

  /// Fetches extended user info using the supplied access token.
  /// Returns null on 401/502 so the caller can refresh and retry.
  Future<CertiliaExtendedInfo?> getExtendedUserInfo(String accessToken) {
    return proxy.fetchExtendedInfo(accessToken);
  }

  void dispose() => proxy.close();
}

/// Extracts the authorization code from a callback URL.
///
/// Throws [CertiliaAuthenticationException] when the user cancelled
/// ([callback] is null), when Certilia returned an OAuth error, when the
/// `state` does not match the one from `/api/auth/initialize`, or when the
/// code is missing.
String codeFromCallback(Uri? callback, {required String expectedState}) {
  if (callback == null) {
    throw const CertiliaAuthenticationException(
      message: 'Authentication was cancelled',
    );
  }
  final params = callback.queryParameters;
  final error = params['error'];
  if (error != null) {
    throw CertiliaAuthenticationException(
      message: params['error_description'] ?? 'Certilia returned an error',
      code: error,
    );
  }
  if (params['state'] != expectedState) {
    throw const CertiliaAuthenticationException(
      message: 'State mismatch in the authorization callback',
      code: 'state_mismatch',
    );
  }
  final code = params['code'];
  if (code == null || code.isEmpty) {
    throw const CertiliaAuthenticationException(
      message: 'No authorization code in the callback',
      code: 'missing_code',
    );
  }
  return code;
}
