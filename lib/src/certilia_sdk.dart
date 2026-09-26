import 'package:flutter/foundation.dart';

import 'certilia_stateful_wrapper.dart';
import 'models/certilia_config.dart';
import 'models/certilia_direct_client.dart';

// createWebClient comes from the web factory on web and from a stub that
// throws elsewhere; mobile and desktop use CertiliaStatefulWrapper instead.
// NB: uvjetni import provjerava dart.library.js_interop, ne
// dart.library.html, jer html postoji samo u dart2js, a js_interop i u
// dart2js i u dart2wasm. Pod --wasm buildom dart.library.html je false, pa
// bi se izabrao stub (createWebClient baca UnsupportedError). Web client
// koristi package:web, pa radi i pod wasm-om.
import 'certilia_sdk_factory.dart'
    if (dart.library.js_interop) 'certilia_sdk_factory_web.dart';

/// Entry point for the Flutter Certilia SDK.
///
/// Normally the SDK talks to a backend proxy (`certilia-server`) that holds
/// the Certilia client secret; the Flutter client only needs its URL:
///
/// ```dart
/// final client = await CertiliaSDK.initialize(
///   serverUrl: 'https://your-backend-server.com',
/// );
/// ```
///
/// Without a server, the app talks to Certilia itself ([direct]) and
/// receives the redirect on an https callback:
///
/// ```dart
/// final client = await CertiliaSDK.initialize(
///   direct: const CertiliaDirectClient(clientId: '...', clientSecret: '...'),
///   callbackUrl: 'https://app.example/certilia_callback.html',
/// );
/// ```
class CertiliaSDK {
  CertiliaSDK._();

  /// Builds the client for the current platform: `CertiliaWebClient` on
  /// web, [CertiliaStatefulWrapper] on mobile and desktop. Both have the
  /// same authenticate, refreshToken, logout, getCurrentUser and
  /// getExtendedUserInfo methods.
  ///
  /// [callbackUrl] selects how the login result reaches the app; see
  /// [CertiliaConfig.callbackUrl]. Pass either [serverUrl] (the proxy) or
  /// [direct] (no server; needs an https [callbackUrl]).
  static Future<dynamic> initialize({
    String? serverUrl,
    CertiliaDirectClient? direct,
    List<String>? scopes,
    bool enableLogging = false,
    bool preferEphemeralSession = true,
    String? callbackUrl,
  }) async {
    final config = CertiliaConfig(
      serverUrl: serverUrl ?? '',
      direct: direct,
      callbackUrl: callbackUrl,
      scopes: scopes ??
          const ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: enableLogging,
      preferEphemeralSession: preferEphemeralSession,
    );
    config.validate();

    if (enableLogging) {
      debugPrint('[CertiliaSDK] Initializing with config: $config');
    }

    if (kIsWeb) {
      return createWebClient(config: config, serverUrl: config.serverUrl);
    }
    return CertiliaStatefulWrapper(config: config, serverUrl: config.serverUrl);
  }
}

/// Backward-compatible alias for the previous entry-point name.
@Deprecated('Use CertiliaSDK instead. Will be removed in 1.0.0.')
typedef CertiliaSDKSimple = CertiliaSDK;
