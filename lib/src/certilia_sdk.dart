import 'package:flutter/foundation.dart';

import 'certilia_stateful_wrapper.dart';
import 'models/certilia_config.dart';
import 'models/certilia_direct_client.dart';

// Platform-specific factory: picks the web popup client on web, the
// WebView-based stateful wrapper on mobile/desktop.
// NB: gate on dart.library.js_interop (NE dart.library.html) jer je html
// dostupan samo u dart2js, dok js_interop postoji i u dart2js i u dart2wasm.
// Pod --wasm build-om dart.library.html je false pa bi se birao non-web stub
// (createWebClient baca UnsupportedError). Web client koristi package:web pa
// je wasm-kompatibilan.
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

  /// Build a platform-appropriate client. The returned object differs by
  /// platform (popup-based on web, [CertiliaStatefulWrapper] on
  /// mobile/desktop) but exposes the same authenticate/refresh/logout/
  /// getCurrentUser/getExtendedUserInfo surface.
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
