/// Constants for Certilia OAuth endpoints and default values
class CertiliaConstants {
  CertiliaConstants._();

  /// Base URL for Certilia login service
  static const String baseUrl = 'https://login.certilia.com';

  /// OAuth authorization endpoint
  static const String authorizationEndpoint = '$baseUrl/oauth/authorize';

  /// OAuth token endpoint
  static const String tokenEndpoint = '$baseUrl/oauth/token';

  /// OAuth user info endpoint
  static const String userInfoEndpoint = '$baseUrl/oauth/userinfo';

  /// OAuth discovery endpoint for auto-configuration
  static const String discoveryEndpoint = '$baseUrl/.well-known/openid-configuration';

  /// Default OAuth scopes
  static const List<String> defaultScopes = ['openid', 'profile', 'eid'];

  /// Default token type
  static const String defaultTokenType = 'Bearer';

  /// User agent string for HTTP requests
  static const String userAgent = 'flutter_certilia/0.1.0';
}