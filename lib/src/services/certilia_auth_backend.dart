import '../models/certilia_extended_info.dart';
import '../models/certilia_user.dart';

/// What the SDK's clients need from the party that holds the Certilia
/// client credentials: build the authorization URL, exchange the code,
/// refresh, and read the user.
///
/// [ProxyAuthService] talks to certilia-server, which keeps the client
/// secret on a server. [DirectAuthService] talks to Certilia itself with a
/// secret shipped in the app (see [CertiliaDirectClient]).
///
/// Token bundles use the proxy's format: `accessToken`, `refreshToken`,
/// `idToken`, `expiresIn`, `tokenType`, and after an exchange `user`.
abstract class CertiliaAuthBackend {
  /// Starts a login. Returns `authorization_url`, `state` and `session_id`.
  ///
  /// [redirectUri] is where Certilia sends the browser after login.
  Future<Map<String, dynamic>> initialize({String? redirectUri});

  /// Exchanges the authorization code of the login started under
  /// [sessionId] for tokens.
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String state,
    required String sessionId,
  });

  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
  });

  /// Basic profile. [idToken] is the stored ID token; the direct backend
  /// reads the profile from it.
  Future<CertiliaUser> fetchUserInfo(String accessToken, {String? idToken});

  /// Full profile, or null when the caller should refresh and retry.
  Future<CertiliaExtendedInfo?> fetchExtendedInfo(
    String accessToken, {
    String? idToken,
  });

  void close();
}
