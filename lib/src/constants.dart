/// Constants for Certilia OAuth endpoints and default values
class CertiliaConstants {
  CertiliaConstants._();

  /// Base URL for Certilia IDP service
  static const String baseUrl = 'https://idp.test.certilia.com';

  /// OAuth authorization endpoint
  static const String authorizationEndpoint = '$baseUrl/oauth2/authorize';

  /// OAuth token endpoint
  static const String tokenEndpoint = '$baseUrl/oauth2/token';

  /// OAuth user info endpoint
  static const String userInfoEndpoint = '$baseUrl/oauth2/userinfo';

  /// OAuth discovery endpoint for auto-configuration
  static const String discoveryEndpoint = '$baseUrl/oauth2/oidcdiscovery/.well-known/openid-configuration';

  /// Default OAuth scopes
  static const List<String> defaultScopes = ['openid', 'profile', 'eid'];

  /// Default token type
  static const String defaultTokenType = 'Bearer';

  /// User agent string for HTTP requests
  static const String userAgent = 'flutter_certilia/0.1.0';
}