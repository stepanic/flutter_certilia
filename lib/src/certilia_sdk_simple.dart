import 'package:flutter/foundation.dart';
import 'certilia_universal_client.dart';
import 'certilia_webview_client.dart';
import 'models/certilia_config.dart';
import 'models/certilia_config_simple.dart';

// Platform-specific factory
import 'certilia_sdk_factory.dart' if (dart.library.html) 'certilia_sdk_factory_web.dart';

/// Simple SDK entry point for client-server architecture
/// This SDK is designed for Flutter clients that communicate with a backend proxy server
class CertiliaSDKSimple {
  CertiliaSDKSimple._();

  /// Initialize the SDK with simplified configuration
  /// 
  /// This method is for Flutter clients that communicate with a backend proxy server.
  /// The backend server handles all OAuth communication with Certilia API.
  /// 
  /// Example usage:
  /// ```dart
  /// final client = await CertiliaSDKSimple.initialize(
  ///   clientId: 'your_client_id',
  ///   serverUrl: 'https://your-backend-server.com',
  /// );
  /// ```
  static Future<dynamic> initialize({
    required String clientId,
    required String serverUrl,
    String? redirectUrl,
    List<String>? scopes,
    bool enableLogging = false,
    bool preferEphemeralSession = true,
    int? sessionTimeout,
  }) async {
    // Create simple config
    final simpleConfig = CertiliaConfigSimple(
      clientId: clientId,
      serverUrl: serverUrl,
      redirectUrl: redirectUrl ?? '$serverUrl/api/auth/callback',
      scopes: scopes ?? ['openid', 'profile', 'eid', 'email', 'offline_access'],
      enableLogging: enableLogging,
      preferEphemeralSession: preferEphemeralSession,
      sessionTimeout: sessionTimeout,
    );

    // Validate configuration
    simpleConfig.validate();

    // Log initialization if enabled
    if (enableLogging) {
      debugPrint('[CertiliaSDKSimple] Initializing with config: $simpleConfig');
    }

    // Convert to full config for compatibility with existing clients
    // For server-based architecture, we don't need real Certilia endpoints
    final fullConfig = CertiliaConfig(
      clientId: simpleConfig.clientId,
      redirectUrl: simpleConfig.redirectUrl,
      serverUrl: simpleConfig.serverUrl,
      scopes: simpleConfig.scopes,
      enableLogging: simpleConfig.enableLogging,
      preferEphemeralSession: simpleConfig.preferEphemeralSession,
      sessionTimeout: simpleConfig.sessionTimeout,
      // These are dummy values since the server handles OAuth
      baseUrl: 'https://idp.certilia.com',
      authorizationEndpoint: 'https://idp.certilia.com/oauth2/authorize',
      tokenEndpoint: 'https://idp.certilia.com/oauth2/token', 
      userInfoEndpoint: 'https://idp.certilia.com/oauth2/userinfo',
    );

    // For client-server architecture, always use WebView or Web client
    if (kIsWeb) {
      return createWebClient(
        config: fullConfig,
        serverUrl: simpleConfig.serverUrl,
      );
    } else {
      // On mobile/desktop, use WebView client for server-based flow
      return CertiliaWebViewClient(
        config: fullConfig,
        serverUrl: simpleConfig.serverUrl,
      );
    }
  }
}