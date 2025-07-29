import 'package:flutter/foundation.dart';
import '../constants.dart';

/// Configuration for Certilia OAuth client
@immutable
class CertiliaConfig {
  /// OAuth client ID
  final String clientId;

  /// OAuth client secret (optional)
  final String? clientSecret;

  /// OAuth redirect URL
  final String redirectUrl;

  /// OAuth scopes to request
  final List<String> scopes;

  /// Base URL for Certilia IDP service
  final String baseUrl;

  /// OAuth authorization endpoint
  final String authorizationEndpoint;

  /// OAuth token endpoint
  final String tokenEndpoint;

  /// OAuth user info endpoint
  final String userInfoEndpoint;

  /// Discovery URL for auto-configuration (optional)
  final String? discoveryUrl;

  /// Server URL for web and WebView implementations (optional)
  final String? serverUrl;

  /// Whether to prefer ephemeral session on iOS
  final bool preferEphemeralSession;

  /// Enable debug logging
  final bool enableLogging;

  /// Custom user agent string (optional)
  final String? customUserAgent;

  /// Session timeout in milliseconds (optional)
  final int? sessionTimeout;

  /// Refresh token timeout in milliseconds (optional)
  final int? refreshTokenTimeout;

  /// Creates a new [CertiliaConfig]
  const CertiliaConfig({
    required this.clientId,
    this.clientSecret,
    required this.redirectUrl,
    this.scopes = CertiliaConstants.defaultScopes,
    this.baseUrl = CertiliaConstants.baseUrl,
    String? authorizationEndpoint,
    String? tokenEndpoint,
    String? userInfoEndpoint,
    this.discoveryUrl,
    this.serverUrl,
    this.preferEphemeralSession = true,
    this.enableLogging = false,
    this.customUserAgent,
    this.sessionTimeout,
    this.refreshTokenTimeout,
  })  : authorizationEndpoint = authorizationEndpoint ?? '$baseUrl/oauth2/authorize',
        tokenEndpoint = tokenEndpoint ?? '$baseUrl/oauth2/token',
        userInfoEndpoint = userInfoEndpoint ?? '$baseUrl/oauth2/userinfo';

  /// Creates a copy of this config with the given fields replaced
  CertiliaConfig copyWith({
    String? clientId,
    String? clientSecret,
    String? redirectUrl,
    List<String>? scopes,
    String? baseUrl,
    String? authorizationEndpoint,
    String? tokenEndpoint,
    String? userInfoEndpoint,
    String? discoveryUrl,
    String? serverUrl,
    bool? preferEphemeralSession,
    bool? enableLogging,
    String? customUserAgent,
    int? sessionTimeout,
    int? refreshTokenTimeout,
  }) {
    return CertiliaConfig(
      clientId: clientId ?? this.clientId,
      clientSecret: clientSecret ?? this.clientSecret,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      scopes: scopes ?? this.scopes,
      baseUrl: baseUrl ?? this.baseUrl,
      authorizationEndpoint: authorizationEndpoint ?? this.authorizationEndpoint,
      tokenEndpoint: tokenEndpoint ?? this.tokenEndpoint,
      userInfoEndpoint: userInfoEndpoint ?? this.userInfoEndpoint,
      discoveryUrl: discoveryUrl ?? this.discoveryUrl,
      serverUrl: serverUrl ?? this.serverUrl,
      preferEphemeralSession: preferEphemeralSession ?? this.preferEphemeralSession,
      enableLogging: enableLogging ?? this.enableLogging,
      customUserAgent: customUserAgent ?? this.customUserAgent,
      sessionTimeout: sessionTimeout ?? this.sessionTimeout,
      refreshTokenTimeout: refreshTokenTimeout ?? this.refreshTokenTimeout,
    );
  }

  /// Validates the configuration
  void validate() {
    if (clientId.isEmpty) {
      throw ArgumentError('clientId cannot be empty');
    }
    if (redirectUrl.isEmpty) {
      throw ArgumentError('redirectUrl cannot be empty');
    }
    if (scopes.isEmpty) {
      throw ArgumentError('scopes cannot be empty');
    }
    if (!redirectUrl.contains('://')) {
      throw ArgumentError('redirectUrl must be a valid URL');
    }
  }

  /// Gets the effective user agent string
  String get userAgent => customUserAgent ?? CertiliaConstants.userAgent;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CertiliaConfig &&
          runtimeType == other.runtimeType &&
          clientId == other.clientId &&
          clientSecret == other.clientSecret &&
          redirectUrl == other.redirectUrl &&
          listEquals(scopes, other.scopes) &&
          baseUrl == other.baseUrl &&
          authorizationEndpoint == other.authorizationEndpoint &&
          tokenEndpoint == other.tokenEndpoint &&
          userInfoEndpoint == other.userInfoEndpoint &&
          discoveryUrl == other.discoveryUrl &&
          serverUrl == other.serverUrl &&
          preferEphemeralSession == other.preferEphemeralSession &&
          enableLogging == other.enableLogging &&
          customUserAgent == other.customUserAgent &&
          sessionTimeout == other.sessionTimeout &&
          refreshTokenTimeout == other.refreshTokenTimeout;

  @override
  int get hashCode =>
      clientId.hashCode ^
      clientSecret.hashCode ^
      redirectUrl.hashCode ^
      scopes.hashCode ^
      baseUrl.hashCode ^
      authorizationEndpoint.hashCode ^
      tokenEndpoint.hashCode ^
      userInfoEndpoint.hashCode ^
      discoveryUrl.hashCode ^
      serverUrl.hashCode ^
      preferEphemeralSession.hashCode ^
      enableLogging.hashCode ^
      customUserAgent.hashCode ^
      sessionTimeout.hashCode ^
      refreshTokenTimeout.hashCode;

  @override
  String toString() {
    return 'CertiliaConfig('
        'clientId: $clientId, '
        'clientSecret: ${clientSecret != null ? '***' : 'null'}, '
        'redirectUrl: $redirectUrl, '
        'scopes: $scopes, '
        'baseUrl: $baseUrl, '
        'authorizationEndpoint: $authorizationEndpoint, '
        'tokenEndpoint: $tokenEndpoint, '
        'userInfoEndpoint: $userInfoEndpoint, '
        'discoveryUrl: $discoveryUrl, '
        'serverUrl: $serverUrl, '
        'preferEphemeralSession: $preferEphemeralSession, '
        'enableLogging: $enableLogging, '
        'customUserAgent: $customUserAgent, '
        'sessionTimeout: $sessionTimeout, '
        'refreshTokenTimeout: $refreshTokenTimeout)';
  }
}