import 'package:flutter/foundation.dart';
import 'certilia_universal_client.dart';
import 'certilia_webview_client.dart';
import 'models/certilia_config.dart';

// Platform-specific factory
import 'certilia_sdk_factory.dart' if (dart.library.html) 'certilia_sdk_factory_web.dart';

/// Main entry point for CertiliaSDK
class CertiliaSDK {
  CertiliaSDK._();

  /// Initialize the SDK with configuration parameters
  /// 
  /// Example usage:
  /// ```dart
  /// final certilia = await CertiliaSDK.initialize(
  ///   config: CertiliaConfig(
  ///     clientId: 'your_client_id',
  ///     clientSecret: 'your_client_secret', // optional
  ///     redirectUrl: 'com.example.app://callback',
  ///     baseUrl: 'https://idp.test.certilia.com',
  ///     authorizationEndpoint: 'https://idp.test.certilia.com/oauth2/authorize',
  ///     tokenEndpoint: 'https://idp.test.certilia.com/oauth2/token',
  ///     userInfoEndpoint: 'https://idp.test.certilia.com/oauth2/userinfo',
  ///     serverUrl: 'https://your-server.com', // for web/webview
  ///     scopes: ['openid', 'profile', 'eid'],
  ///     enableLogging: true,
  ///   ),
  /// );
  /// ```
  static Future<dynamic> initialize({
    required CertiliaConfig config,
    bool? forceWebView,
  }) async {
    // Validate configuration
    config.validate();

    // Log initialization if enabled
    if (config.enableLogging) {
      debugPrint('[CertiliaSDK] Initializing with config: $config');
    }

    // Auto-select implementation based on platform and parameters
    if (kIsWeb) {
      // Web platform - use web client
      if (config.serverUrl == null) {
        throw ArgumentError(
          'serverUrl is required for web platform. '
          'Please provide it in CertiliaConfig.',
        );
      }
      return createWebClient(
        config: config,
        serverUrl: config.serverUrl!,
      );
    } else if (forceWebView == true) {
      // Force WebView implementation
      if (config.serverUrl == null) {
        throw ArgumentError(
          'serverUrl is required for WebView implementation. '
          'Please provide it in CertiliaConfig.',
        );
      }
      return CertiliaWebViewClient(
        config: config,
        serverUrl: config.serverUrl!,
      );
    } else {
      // Mobile/Desktop - use universal client (AppAuth with WebView fallback)
      return CertiliaUniversalClient(
        config: config,
        serverUrl: config.serverUrl,
      );
    }
  }

  /// Create a basic configuration with minimal required parameters
  /// 
  /// This is a convenience method that creates a config with default Certilia endpoints
  static CertiliaConfig createBasicConfig({
    required String clientId,
    required String redirectUrl,
    String? clientSecret,
    String? serverUrl,
    List<String>? scopes,
    bool enableLogging = false,
    String baseUrl = 'https://idp.test.certilia.com',
  }) {
    return CertiliaConfig(
      clientId: clientId,
      clientSecret: clientSecret,
      redirectUrl: redirectUrl,
      serverUrl: serverUrl,
      scopes: scopes ?? ['openid', 'profile', 'eid'],
      enableLogging: enableLogging,
      baseUrl: baseUrl,
      // Endpoints will be auto-generated from baseUrl
    );
  }
}