import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:http/http.dart' as http;
import 'package:pointycastle/export.dart' as pc;

import '../exceptions/certilia_exception.dart';
import '../models/certilia_direct_client.dart';
import '../models/certilia_extended_info.dart';
import '../models/certilia_user.dart';
import 'certilia_auth_backend.dart';
import 'certilia_logger.dart';

/// [CertiliaAuthBackend] that talks to Certilia directly, with the client
/// secret shipped in the app (see [CertiliaDirectClient] for what that
/// exposes).
///
/// The login is the PKCE authorization code flow. The token endpoint
/// accepts cross-origin requests, so this also works from a browser. The
/// ID token is accepted only after its RS256 signature verifies against
/// Certilia's JWKS and `iss`, `aud`, `exp` and `nonce` check out; the user
/// profile then comes from its claims, because Certilia's userinfo endpoint
/// only answers requests that carry the token-binding cookie of the
/// browser that logged in.
class DirectAuthService implements CertiliaAuthBackend {
  final CertiliaDirectClient client;
  final List<String> scopes;
  final http.Client _http;
  final CertiliaLogger _logger;
  final DateTime Function() _now;
  final Random _random;

  /// Logins started by [initialize] and not yet exchanged, by session id.
  final Map<String, _PendingLogin> _pending = {};

  /// Certilia's signing keys by `kid`, fetched on first use.
  Map<String, pc.RSAPublicKey>? _jwks;

  static const Duration _timeout = Duration(seconds: 30);
  static const Duration _clockSkew = Duration(minutes: 2);
  static const Duration _pendingLifetime = Duration(minutes: 10);

  DirectAuthService({
    required this.client,
    required this.scopes,
    required CertiliaLogger logger,
    http.Client? httpClient,
    DateTime Function()? now,
    Random? random,
  })  : _http = httpClient ?? http.Client(),
        _logger = logger,
        _now = now ?? DateTime.now,
        _random = random ?? Random.secure();

  @override
  Future<Map<String, dynamic>> initialize({String? redirectUri}) async {
    if (redirectUri == null) {
      throw const CertiliaConfigurationException(
        message: 'Direct mode needs a callbackUrl',
      );
    }
    _pending.removeWhere(
        (_, p) => _now().difference(p.createdAt) > _pendingLifetime);

    final verifier = _randomToken(32);
    final state = _randomToken(16);
    final nonce = _randomToken(16);
    final sessionId = _randomToken(16);
    final challenge = _b64url(crypto.sha256.convert(ascii.encode(verifier)).bytes);

    _pending[sessionId] = _PendingLogin(
      verifier: verifier,
      state: state,
      nonce: nonce,
      redirectUri: redirectUri,
      createdAt: _now(),
    );

    final url = Uri.parse('${client.issuerBaseUrl}/oauth2/authorize').replace(
      queryParameters: {
        'client_id': client.clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': scopes.join(' '),
        'state': state,
        'nonce': nonce,
        'code_challenge': challenge,
        'code_challenge_method': 'S256',
        'prompt': 'login',
        // Same request as certilia-server: ask for the OIB in the ID token.
        'claims': jsonEncode({
          'id_token': {
            'pin': {'essential': true}
          }
        }),
      },
    );
    _logger.log('Direct login started, redirect URI: $redirectUri');
    return {
      'authorization_url': url.toString(),
      'state': state,
      'session_id': sessionId,
    };
  }

  @override
  Future<Map<String, dynamic>> exchange({
    required String code,
    required String state,
    required String sessionId,
  }) async {
    final pending = _pending.remove(sessionId);
    if (pending == null) {
      throw const CertiliaAuthenticationException(
        message: 'Unknown or expired login session',
        code: 'invalid_session',
      );
    }
    if (pending.state != state) {
      throw const CertiliaAuthenticationException(
        message: 'State mismatch in the authorization callback',
        code: 'state_mismatch',
      );
    }

    final tokens = await _tokenRequest({
      'grant_type': 'authorization_code',
      'code': code,
      'redirect_uri': pending.redirectUri,
      'code_verifier': pending.verifier,
    }, 'exchange');

    final idToken = tokens['id_token'] as String?;
    if (idToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'Certilia returned no ID token',
        code: 'missing_id_token',
      );
    }
    final claims = await verifyIdToken(idToken, nonce: pending.nonce);
    _logger.log('ID token verified');

    return {
      ..._bundle(tokens),
      'user': _userJson(claims),
    };
  }

  /// Certilia currently answers refresh requests for portal clients with
  /// `invalid_grant` ("Persisted access token data not found"), from a
  /// server as well as from a browser; the error reaches the caller.
  ///
  /// A refreshed ID token is verified before it is returned, because
  /// [fetchUserInfo] and [fetchExtendedInfo] trust the stored one. Without
  /// a new ID token the bundle keeps [idToken].
  @override
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
    String? idToken,
  }) async {
    final tokens = await _tokenRequest({
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    }, 'refresh');
    final bundle = _bundle(tokens);
    bundle['refreshToken'] ??= refreshToken;
    final refreshedIdToken = tokens['id_token'] as String?;
    if (refreshedIdToken == null) {
      bundle['idToken'] = idToken;
    } else {
      await _verifyRefreshedIdToken(refreshedIdToken, loginIdToken: idToken);
    }
    return bundle;
  }

  @override
  Future<CertiliaUser> fetchUserInfo(String accessToken,
      {String? idToken}) async {
    return CertiliaUser.fromJson(_userJson(_storedClaims(idToken)));
  }

  @override
  Future<CertiliaExtendedInfo?> fetchExtendedInfo(String accessToken,
      {String? idToken}) async {
    final claims = _storedClaims(idToken);
    final exp = claims['exp'];
    return CertiliaExtendedInfo(
      userInfo: claims,
      availableFields: claims.keys.toList(),
      tokenExpiry: exp is int
          ? DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true)
          : null,
    );
  }

  @override
  void close() => _http.close();

  /// Verifies the ID token of a login and returns its claims.
  ///
  /// Checks the RS256 signature against Certilia's JWKS, `iss`, that `aud`
  /// contains the client id, `exp` (with two minutes of clock skew) and
  /// [nonce].
  Future<Map<String, dynamic>> verifyIdToken(String idToken,
      {required String nonce}) async {
    final claims = await _verifySignedClaims(idToken);
    if (claims['nonce'] != nonce) throw _invalidToken('nonce mismatch');
    return claims;
  }

  /// Verifies an ID token from a refresh response the way OpenID Connect
  /// Core 12.2 asks: the checks of [verifyIdToken] except the nonce, the
  /// same `sub` as [loginIdToken], and a `nonce`, if present, equal to
  /// [loginIdToken]'s. Without [loginIdToken] there is nothing to compare
  /// against, so the refreshed token must not carry a nonce.
  Future<Map<String, dynamic>> _verifyRefreshedIdToken(String idToken,
      {String? loginIdToken}) async {
    final claims = await _verifySignedClaims(idToken);
    final login = loginIdToken == null
        ? const <String, dynamic>{}
        : _storedClaims(loginIdToken);
    if (loginIdToken != null && claims['sub'] != login['sub']) {
      throw _invalidToken('subject changed on refresh');
    }
    if (claims.containsKey('nonce') && claims['nonce'] != login['nonce']) {
      throw _invalidToken('nonce mismatch');
    }
    return claims;
  }

  /// Checks signature, `iss`, `aud` and `exp` of [idToken] and returns its
  /// claims.
  Future<Map<String, dynamic>> _verifySignedClaims(String idToken) async {
    final parts = idToken.split('.');
    if (parts.length != 3) throw _invalidToken('not a JWT');
    final Map<String, dynamic> header;
    final Map<String, dynamic> claims;
    try {
      header = _decodeJsonPart(parts[0]);
      claims = _decodeJsonPart(parts[1]);
    } catch (_) {
      throw _invalidToken('undecodable');
    }
    if (header['alg'] != 'RS256') {
      throw _invalidToken('unexpected alg ${header['alg']}');
    }

    var key = (await _keys())[header['kid']];
    if (key == null) {
      _jwks = null; // Certilia may have rotated its keys
      key = (await _keys())[header['kid']];
    }
    if (key == null) throw _invalidToken('unknown signing key');

    final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
      ..init(false, pc.PublicKeyParameter<pc.RSAPublicKey>(key));
    final valid = signer.verifySignature(
      Uint8List.fromList(ascii.encode('${parts[0]}.${parts[1]}')),
      pc.RSASignature(_b64urlDecode(parts[2])),
    );
    if (!valid) throw _invalidToken('bad signature');

    if (claims['iss'] != client.issuer) throw _invalidToken('wrong issuer');
    final aud = claims['aud'];
    final audiences = aud is List ? aud : [aud];
    if (!audiences.contains(client.clientId)) {
      throw _invalidToken('wrong audience');
    }
    final exp = claims['exp'];
    if (exp is! int ||
        DateTime.fromMillisecondsSinceEpoch(exp * 1000)
            .add(_clockSkew)
            .isBefore(_now())) {
      throw _invalidToken('expired');
    }
    return claims;
  }

  Future<Map<String, dynamic>> _tokenRequest(
      Map<String, String> params, String op) async {
    final response = await _http
        .post(
          Uri.parse('${client.issuerBaseUrl}/oauth2/token'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {
            ...params,
            'client_id': client.clientId,
            'client_secret': client.clientSecret,
          },
        )
        .timeout(_timeout,
            onTimeout: () => throw CertiliaNetworkException(
                  message: '$op request timed out',
                  statusCode: 408,
                ));
    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      body = {};
    }
    if (response.statusCode != 200) {
      final error = body['error'] as String?;
      // An OAuth error response means Certilia refused the request; anything
      // else (a 5xx, a proxy's HTML page) is an outage worth retrying.
      if (error == null) {
        throw CertiliaNetworkException(
          message: 'Certilia token $op failed',
          statusCode: response.statusCode,
        );
      }
      throw CertiliaAuthenticationException(
        message: (body['error_description'] as String?) ??
            'Certilia token $op failed',
        code: error,
        details: 'HTTP ${response.statusCode}',
      );
    }
    return body;
  }

  Future<Map<String, pc.RSAPublicKey>> _keys() async {
    if (_jwks != null) return _jwks!;
    final response = await _http
        .get(Uri.parse('${client.issuerBaseUrl}/oauth2/jwks'))
        .timeout(_timeout);
    if (response.statusCode != 200) {
      throw CertiliaNetworkException(
        message: 'Failed to fetch Certilia signing keys',
        statusCode: response.statusCode,
      );
    }
    final keys = (jsonDecode(response.body)['keys'] as List)
        .cast<Map<String, dynamic>>()
        .where((k) => k['kty'] == 'RSA');
    return _jwks = {
      for (final k in keys)
        k['kid'] as String: pc.RSAPublicKey(
          _bigInt(_b64urlDecode(k['n'] as String)),
          _bigInt(_b64urlDecode(k['e'] as String)),
        ),
    };
  }

  /// Claims of an ID token this backend verified before it was stored.
  Map<String, dynamic> _storedClaims(String? idToken) {
    if (idToken == null) {
      throw const CertiliaAuthenticationException(
        message: 'No ID token stored; log in again',
        code: 'missing_id_token',
      );
    }
    try {
      return _decodeJsonPart(idToken.split('.')[1]);
    } catch (_) {
      throw _invalidToken('undecodable');
    }
  }

  static Map<String, dynamic> _bundle(Map<String, dynamic> tokens) => {
        'accessToken': tokens['access_token'],
        'refreshToken': tokens['refresh_token'],
        'idToken': tokens['id_token'],
        'expiresIn': tokens['expires_in'],
        'tokenType': tokens['token_type'] ?? 'Bearer',
      };

  static Map<String, dynamic> _userJson(Map<String, dynamic> claims) {
    const skip = {'aud', 'azp', 'iss', 'iat', 'nbf', 'exp', 'nonce', 'at_hash', 'c_hash'};
    return {
      for (final e in claims.entries)
        if (!skip.contains(e.key)) e.key: e.value,
    };
  }

  static CertiliaAuthenticationException _invalidToken(String why) =>
      CertiliaAuthenticationException(
        message: 'ID token rejected: $why',
        code: 'invalid_id_token',
      );

  String _randomToken(int bytes) =>
      _b64url(List<int>.generate(bytes, (_) => _random.nextInt(256)));

  static String _b64url(List<int> bytes) =>
      base64Url.encode(bytes).replaceAll('=', '');

  static Uint8List _b64urlDecode(String s) =>
      base64Url.decode(s.padRight(s.length + (4 - s.length % 4) % 4, '='));

  static Map<String, dynamic> _decodeJsonPart(String part) =>
      jsonDecode(utf8.decode(_b64urlDecode(part))) as Map<String, dynamic>;

  static BigInt _bigInt(Uint8List bytes) =>
      bytes.fold(BigInt.zero, (acc, b) => (acc << 8) | BigInt.from(b));
}

class _PendingLogin {
  final String verifier;
  final String state;
  final String nonce;
  final String redirectUri;
  final DateTime createdAt;

  _PendingLogin({
    required this.verifier,
    required this.state,
    required this.nonce,
    required this.redirectUri,
    required this.createdAt,
  });
}
