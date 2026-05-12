import 'package:flutter/foundation.dart';

import 'certilia_stateful_wrapper.dart';
import 'models/certilia_config.dart';

// Platform-specific factory: picks the web popup client on web, the
// WebView-based stateful wrapper on mobile/desktop.
import 'certilia_sdk_factory.dart'
    if (dart.library.html) 'certilia_sdk_factory_web.dart';

/// Entry point for the Flutter Certilia SDK.
///
/// The SDK is designed around a backend proxy (`certilia-server`) that
/// handles all OAuth communication with Certilia. The Flutter client only
/// needs to know the URL of that proxy.
///
/// ```dart
/// final client = await CertiliaSDK.initialize(
///   serverUrl: 'https://your-backend-server.com',
/// );
/// ```
class CertiliaSDK {
  CertiliaSDK._();

  /// Build a platform-appropriate client. The returned object differs by
  /// platform (popup-based on web, WebView+stateful-wrapper on
  /// mobile/desktop) but exposes the same authenticate/refresh/logout/
  /// getCurrentUser/getExtendedUserInfo surface.
  static Future<dynamic> initialize({
    required String serverUrl,
    List<String>? scopes,
    bool enableLogging = false,
    bool preferEphemeralSession = true,
    int? sessionTimeout,
  }) async {
    final config = CertiliaConfig(
      serverUrl: serverUrl,
      scopes: scopes ??
          const ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: enableLogging,
      preferEphemeralSession: preferEphemeralSession,
      sessionTimeout: sessionTimeout,
    );
    config.validate();

    if (enableLogging) {
      debugPrint('[CertiliaSDK] Initializing with config: $config');
    }

    if (kIsWeb) {
      return createWebClient(config: config, serverUrl: serverUrl);
    }
    return CertiliaStatefulWrapper(config: config, serverUrl: serverUrl);
  }
}

/// Backward-compatible alias for the previous entry-point name.
@Deprecated('Use CertiliaSDK instead. Will be removed in 1.0.0.')
typedef CertiliaSDKSimple = CertiliaSDK;
