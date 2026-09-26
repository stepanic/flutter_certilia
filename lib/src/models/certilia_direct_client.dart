import 'package:flutter/foundation.dart';

/// A Certilia OAuth client the app uses directly, without certilia-server.
///
/// Certilia only issues confidential clients: its token endpoint refuses a
/// code exchange without the client secret. In direct mode that secret
/// is compiled into the app, where anyone can read it. What protects the login
/// is then the exact redirect match and PKCE: Certilia sends the
/// authorization code only to the registered callback, and a code is
/// useless without the PKCE verifier of the login that requested it. With
/// an https callback (a page on the app's origin, an Android App Link, an
/// iOS Universal Link) the code can only reach your app. Someone holding the
/// secret can still start logins that show your service name and spend
/// your client's login quota; with a custom-scheme callback another app on
/// the device could also receive the redirect, so direct mode requires an
/// https callback.
///
/// Check Certilia's terms before putting a client secret in an app.
@immutable
class CertiliaDirectClient {
  final String clientId;
  final String clientSecret;

  /// Certilia's base URL. Production: `https://idp.certilia.com`; test
  /// environment: `https://idp.test.certilia.com`.
  final String issuerBaseUrl;

  const CertiliaDirectClient({
    required this.clientId,
    required this.clientSecret,
    this.issuerBaseUrl = 'https://idp.certilia.com',
  });

  /// The `iss` claim of Certilia's ID tokens.
  String get issuer => '$issuerBaseUrl/oauth2/token';

  @override
  bool operator ==(Object other) =>
      other is CertiliaDirectClient &&
      clientId == other.clientId &&
      clientSecret == other.clientSecret &&
      issuerBaseUrl == other.issuerBaseUrl;

  @override
  int get hashCode => Object.hash(clientId, clientSecret, issuerBaseUrl);

  @override
  String toString() =>
      'CertiliaDirectClient(clientId: $clientId, issuerBaseUrl: $issuerBaseUrl)';
}
