import 'package:flutter/widgets.dart';

import 'exceptions/certilia_exception.dart';
import 'models/certilia_config.dart';
import 'models/certilia_extended_info.dart';
import 'models/certilia_user.dart';
import 'oauth_callback.dart';
import 'services/certilia_logger.dart';
import 'services/auth_backend_factory.dart';
import 'services/certilia_auth_backend.dart';

/// OAuth flow shared by the mobile/desktop clients.
///
/// The [backend] builds the authorization URL and exchanges the code: the
/// proxy, which keeps the client secret on a server, or in direct mode
/// Certilia itself (Certilia only issues confidential clients, so one of
/// them must present the secret). Subclasses decide how the user
/// reaches Certilia's login page and how the redirect comes back to the
/// app: [CertiliaWebViewClient] watches an in-app WebView for the proxy's
/// callback URL, [CertiliaBrowserClient] lets the system browser return a
/// custom-scheme or App Link redirect.
///
/// Stateless: callers (typically [CertiliaStatefulWrapper]) store tokens.
abstract class CertiliaNativeClient {
  final CertiliaConfig config;
  final String serverUrl;
  final CertiliaAuthBackend backend;
  final CertiliaLogger logger;

  CertiliaNativeClient({
    required this.config,
    required this.serverUrl,
    required String componentName,
    CertiliaAuthBackend? backend,
  })  : logger = CertiliaLogger(
          componentName: componentName,
          enableLogging: config.enableLogging,
        ),
        backend = backend ??
            createAuthBackend(
              config: config,
              serverUrl: serverUrl,
              componentName: componentName,
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
      final authData = await backend.initialize(redirectUri: redirectUri);
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

      final tokenData = await backend.exchange(
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
      final tokenData = await backend.refresh(
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
  Future<CertiliaUser?> getUserInfo(String accessToken,
      {String? idToken}) async {
    try {
      return await backend.fetchUserInfo(accessToken, idToken: idToken);
    } catch (e) {
      logger.log('Failed to get user info: $e');
      return null;
    }
  }

  /// Fetches extended user info using the supplied access token.
  /// Returns null on 401/502 so the caller can refresh and retry.
  Future<CertiliaExtendedInfo?> getExtendedUserInfo(String accessToken,
      {String? idToken}) {
    return backend.fetchExtendedInfo(accessToken, idToken: idToken);
  }

  void dispose() => backend.close();
}
