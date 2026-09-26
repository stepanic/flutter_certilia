import 'package:flutter/foundation.dart';

import 'certilia_direct_client.dart';

/// Configuration for the Flutter Certilia SDK.
///
/// Normally the SDK talks to your backend proxy (`certilia-server`), which
/// holds the Certilia client secret; then [serverUrl] is the only required
/// value. With [direct] set, the SDK talks to Certilia itself and needs no
/// server; see [CertiliaDirectClient] for what that exposes.
@immutable
class CertiliaConfig {
  /// Backend proxy server URL. Empty in direct mode.
  final String serverUrl;

  /// Certilia client used directly, without the proxy. Requires an https
  /// [callbackUrl].
  final CertiliaDirectClient? direct;

  /// OAuth scopes the proxy should request. The proxy server is free to
  /// override or extend this list.
  final List<String> scopes;

  /// Prefer iOS ephemeral session (no shared cookies) where supported.
  final bool preferEphemeralSession;

  /// Enable verbose SDK logging.
  final bool enableLogging;

  /// Where Certilia sends the browser after login, when the app receives
  /// the redirect itself. Certilia registers one callback URL per client,
  /// so this must be exactly the callback of a client the proxy knows
  /// (see `CERTILIA_CLIENTS` in certilia-server).
  ///
  /// - `null` (default): Certilia redirects to the proxy's own
  ///   `/api/auth/callback`. Mobile uses an in-app WebView that watches for
  ///   that URL; web uses a popup and polls the proxy.
  /// - Mobile, custom scheme or https App Link / Universal Link: the login
  ///   runs in the system browser (Android Auth Tab / Custom Tabs, iOS
  ///   ASWebAuthenticationSession), which returns the redirect to the app.
  /// - Web, a page on the app's own origin (e.g. `https://app.example/certilia_callback.html`):
  ///   the login runs in a popup and that page reports the result to the
  ///   app over BroadcastChannel; no polling.
  final String? callbackUrl;

  const CertiliaConfig({
    required this.serverUrl,
    this.scopes = const ['openid', 'profile', 'eid'],
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.callbackUrl,
    this.direct,
  });

  void validate() {
    if (direct == null) {
      if (serverUrl.isEmpty) {
        throw ArgumentError('serverUrl cannot be empty');
      }
      if (!serverUrl.startsWith('http')) {
        throw ArgumentError('serverUrl must be a valid HTTP(S) URL');
      }
    } else {
      // Only an https callback keeps the code away from other apps; the
      // WebView and polling flows need the proxy's own callback.
      if (callbackUrl == null || Uri.tryParse(callbackUrl!)?.scheme != 'https') {
        throw ArgumentError('direct mode needs an https callbackUrl');
      }
      if (direct!.clientId.isEmpty || direct!.clientSecret.isEmpty) {
        throw ArgumentError('direct mode needs clientId and clientSecret');
      }
    }
    if (scopes.isEmpty) {
      throw ArgumentError('scopes cannot be empty');
    }
    if (callbackUrl != null) {
      final uri = Uri.tryParse(callbackUrl!);
      if (uri == null || uri.scheme.isEmpty) {
        throw ArgumentError('callbackUrl must be an absolute URI');
      }
      if (uri.scheme == 'http' && uri.host != 'localhost') {
        throw ArgumentError('callbackUrl must use https or a custom scheme');
      }
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaConfig &&
          runtimeType == other.runtimeType &&
          serverUrl == other.serverUrl &&
          listEquals(scopes, other.scopes) &&
          preferEphemeralSession == other.preferEphemeralSession &&
          enableLogging == other.enableLogging &&
          callbackUrl == other.callbackUrl &&
          direct == other.direct;

  @override
  int get hashCode =>
      serverUrl.hashCode ^
      scopes.hashCode ^
      preferEphemeralSession.hashCode ^
      enableLogging.hashCode ^
      callbackUrl.hashCode ^
      direct.hashCode;

  @override
  String toString() {
    return 'CertiliaConfig('
        'serverUrl: $serverUrl, '
        'scopes: $scopes, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'callbackUrl: $callbackUrl, '
        'direct: $direct)';
  }
}

/// Backward-compatible alias for the previous name.
@Deprecated('Use CertiliaConfig instead. Will be removed in 1.0.0.')
typedef CertiliaConfigSimple = CertiliaConfig;
