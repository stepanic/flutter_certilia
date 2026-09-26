import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pointycastle/export.dart' as pc;

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/services/certilia_logger.dart';
import 'package:flutter_certilia/src/services/direct_auth_service.dart';

const _client = CertiliaDirectClient(
  clientId: 'client-1',
  clientSecret: 'secret-1',
  issuerBaseUrl: 'https://idp.example',
);
const _callback = 'https://app.example/certilia_callback.html';
final _now = DateTime.utc(2026, 9, 26, 12);

String _b64(List<int> bytes) => base64Url.encode(bytes).replaceAll('=', '');

Uint8List _bytes(BigInt n) {
  final hex = n.toRadixString(16);
  final even = hex.length.isOdd ? '0$hex' : hex;
  return Uint8List.fromList([
    for (var i = 0; i < even.length; i += 2)
      int.parse(even.substring(i, i + 2), radix: 16),
  ]);
}

pc.AsymmetricKeyPair<pc.RSAPublicKey, pc.RSAPrivateKey> _keyPair(int seed) {
  final random = pc.FortunaRandom()
    ..seed(pc.KeyParameter(Uint8List.fromList(
        List<int>.generate(32, (i) => (i * 7 + seed) % 256))));
  final gen = pc.RSAKeyGenerator()
    ..init(pc.ParametersWithRandom(
        pc.RSAKeyGeneratorParameters(BigInt.from(65537), 1024, 64), random));
  final pair = gen.generateKeyPair();
  return pc.AsymmetricKeyPair(pair.publicKey, pair.privateKey);
}

final _certiliaKey = _keyPair(1);
final _otherKey = _keyPair(2);

String _sign(Map<String, dynamic> claims,
    {pc.RSAPrivateKey? key, String kid = 'k1', String alg = 'RS256'}) {
  final head = _b64(utf8.encode(jsonEncode({'alg': alg, 'kid': kid})));
  final body = _b64(utf8.encode(jsonEncode(claims)));
  final signer = pc.RSASigner(pc.SHA256Digest(), '0609608648016503040201')
    ..init(true, pc.PrivateKeyParameter<pc.RSAPrivateKey>(key ?? _certiliaKey.privateKey));
  final sig = signer.generateSignature(Uint8List.fromList(ascii.encode('$head.$body')));
  return '$head.$body.${_b64(sig.bytes)}';
}

Map<String, dynamic> _claims({
  required String nonce,
  Object aud = 'client-1',
  String iss = 'https://idp.example/oauth2/token',
  Duration expiresIn = const Duration(hours: 1),
}) =>
    {
      'iss': iss,
      'aud': aud,
      'sub': 'user-1',
      'given_name': 'Ana',
      'family_name': 'Horvat',
      'email': 'ana@example.com',
      'nonce': nonce,
      'iat': _now.millisecondsSinceEpoch ~/ 1000,
      'exp': _now.add(expiresIn).millisecondsSinceEpoch ~/ 1000,
    };

/// Fake Certilia: JWKS with k1, and a token endpoint whose ID token is built
/// by [idToken] from the nonce of the authorization URL.
class _FakeCertilia {
  final String Function(String nonce) idToken;
  final requests = <http.Request>[];
  String? nonce;

  _FakeCertilia(this.idToken);

  late final MockClient client = MockClient((request) async {
    requests.add(request);
    if (request.url.path == '/oauth2/jwks') {
      return http.Response(
        jsonEncode({
          'keys': [
            {
              'kty': 'RSA',
              'kid': 'k1',
              'n': _b64(_bytes(_certiliaKey.publicKey.modulus!)),
              'e': _b64(_bytes(_certiliaKey.publicKey.exponent!)),
            }
          ]
        }),
        200,
      );
    }
    if (request.url.path == '/oauth2/token') {
      return http.Response(
        jsonEncode({
          'access_token': 'at',
          'refresh_token': 'rt',
          'id_token': idToken(nonce!),
          'expires_in': 3600,
          'token_type': 'Bearer',
        }),
        200,
      );
    }
    return http.Response('not found', 404);
  });

  DirectAuthService service() => DirectAuthService(
        client: _client,
        scopes: const ['openid', 'profile'],
        logger: CertiliaLogger(componentName: 'test', enableLogging: false),
        httpClient: client,
        now: () => _now,
        random: Random(42),
      );

  /// Runs initialize + exchange and returns the bundle.
  Future<Map<String, dynamic>> login({String? state}) async {
    final s = service();
    final init = await s.initialize(redirectUri: _callback);
    nonce = Uri.parse(init['authorization_url'] as String)
        .queryParameters['nonce'];
    return s.exchange(
      code: 'the-code',
      state: state ?? init['state'] as String,
      sessionId: init['session_id'] as String,
    );
  }
}

Matcher _rejected(String why) => throwsA(isA<CertiliaAuthenticationException>()
    .having((e) => e.message, 'message', contains(why)));

void main() {
  group('DirectAuthService.initialize', () {
    test('builds a PKCE S256 authorization URL at Certilia', () async {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n)));
      final init = await fake.service().initialize(redirectUri: _callback);
      final url = Uri.parse(init['authorization_url'] as String);
      expect(url.origin, 'https://idp.example');
      expect(url.path, '/oauth2/authorize');
      final q = url.queryParameters;
      expect(q['client_id'], 'client-1');
      expect(q['redirect_uri'], _callback);
      expect(q['response_type'], 'code');
      expect(q['code_challenge_method'], 'S256');
      expect(q['state'], init['state']);
      expect(q['nonce'], isNotEmpty);
      expect(q, isNot(contains('client_secret')));
    });

    test('needs a redirect URI', () {
      final fake = _FakeCertilia((n) => '');
      expect(fake.service().initialize(),
          throwsA(isA<CertiliaConfigurationException>()));
    });
  });

  group('DirectAuthService.exchange', () {
    test('sends secret and PKCE verifier, returns user from verified ID token',
        () async {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n)));
      final s = fake.service();
      final init = await s.initialize(redirectUri: _callback);
      final authUrl = Uri.parse(init['authorization_url'] as String);
      fake.nonce = authUrl.queryParameters['nonce'];

      final bundle = await s.exchange(
        code: 'the-code',
        state: init['state'] as String,
        sessionId: init['session_id'] as String,
      );

      final tokenReq = fake.requests.firstWhere((r) => r.url.path == '/oauth2/token');
      final form = Uri.splitQueryString(tokenReq.body);
      expect(form['client_secret'], 'secret-1');
      expect(form['code'], 'the-code');
      expect(form['redirect_uri'], _callback);
      final challenge = _b64(crypto.sha256.convert(ascii.encode(form['code_verifier']!)).bytes);
      expect(challenge, authUrl.queryParameters['code_challenge']);

      expect(bundle['accessToken'], 'at');
      expect(bundle['refreshToken'], 'rt');
      final user = CertiliaUser.fromJson(bundle['user'] as Map<String, dynamic>);
      expect(user.sub, 'user-1');
      expect(user.firstName, 'Ana');
      expect((bundle['user'] as Map).containsKey('nonce'), isFalse);
    });

    test('rejects a token signed by another key', () {
      final fake = _FakeCertilia(
          (n) => _sign(_claims(nonce: n), key: _otherKey.privateKey));
      expect(fake.login(), _rejected('bad signature'));
    });

    test('rejects a tampered payload', () {
      final fake = _FakeCertilia((n) {
        final parts = _sign(_claims(nonce: n)).split('.');
        final forged = _b64(utf8.encode(jsonEncode({..._claims(nonce: n), 'sub': 'someone-else'})));
        return '${parts[0]}.$forged.${parts[2]}';
      });
      expect(fake.login(), _rejected('bad signature'));
    });

    test('rejects another audience', () {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n, aud: 'other-client')));
      expect(fake.login(), _rejected('wrong audience'));
    });

    test('rejects another issuer', () {
      final fake = _FakeCertilia(
          (n) => _sign(_claims(nonce: n, iss: 'https://evil.example/oauth2/token')));
      expect(fake.login(), _rejected('wrong issuer'));
    });

    test('rejects an expired token', () {
      final fake = _FakeCertilia(
          (n) => _sign(_claims(nonce: n, expiresIn: const Duration(minutes: -10))));
      expect(fake.login(), _rejected('expired'));
    });

    test('rejects a replayed token with another nonce', () {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: 'old-nonce')));
      expect(fake.login(), _rejected('nonce mismatch'));
    });

    test('rejects an unknown signing key id', () {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n), kid: 'k9'));
      expect(fake.login(), _rejected('unknown signing key'));
    });

    test('rejects a state mismatch before calling Certilia', () async {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n)));
      await expectLater(
        fake.login(state: 'forged'),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'state_mismatch')),
      );
      expect(fake.requests, isEmpty);
    });

    test('a session can be exchanged only once', () async {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n)));
      final s = fake.service();
      final init = await s.initialize(redirectUri: _callback);
      fake.nonce = Uri.parse(init['authorization_url'] as String).queryParameters['nonce'];
      await s.exchange(code: 'c', state: init['state'] as String, sessionId: init['session_id'] as String);
      expect(
        s.exchange(code: 'c', state: init['state'] as String, sessionId: init['session_id'] as String),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'invalid_session')),
      );
    });

    test('reports Certilia errors with their description', () async {
      final s = DirectAuthService(
        client: _client,
        scopes: const ['openid'],
        logger: CertiliaLogger(componentName: 'test', enableLogging: false),
        httpClient: MockClient((_) async => http.Response(
            jsonEncode({'error': 'invalid_grant', 'error_description': 'Persisted access token data not found'}),
            400)),
      );
      expect(
        s.refresh(accessToken: 'at', refreshToken: 'rt'),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'invalid_grant')
            .having((e) => e.message, 'message', 'Persisted access token data not found')),
      );
    });
  });

  group('DirectAuthService.refresh', () {
    DirectAuthService refreshing(Map<String, dynamic> response,
            {int status = 200}) =>
        DirectAuthService(
          client: _client,
          scopes: const ['openid'],
          logger: CertiliaLogger(componentName: 'test', enableLogging: false),
          httpClient: MockClient((request) async {
            if (request.url.path == '/oauth2/jwks') {
              return http.Response(
                jsonEncode({
                  'keys': [
                    {
                      'kty': 'RSA',
                      'kid': 'k1',
                      'n': _b64(_bytes(_certiliaKey.publicKey.modulus!)),
                      'e': _b64(_bytes(_certiliaKey.publicKey.exponent!)),
                    }
                  ]
                }),
                200,
              );
            }
            return http.Response(jsonEncode(response), status);
          }),
          now: () => _now,
        );

    final loginIdToken = _sign(_claims(nonce: 'login-nonce'));

    test('keeps the login ID token when the response has none', () async {
      final bundle = await refreshing({'access_token': 'at-2'}).refresh(
          accessToken: 'at', refreshToken: 'rt', idToken: loginIdToken);
      expect(bundle['accessToken'], 'at-2');
      expect(bundle['idToken'], loginIdToken);
      expect(bundle['refreshToken'], 'rt');
    });

    test('accepts a refreshed ID token of the same subject without nonce',
        () async {
      final refreshed = _sign(_claims(nonce: '')..remove('nonce'));
      final bundle = await refreshing(
              {'access_token': 'at-2', 'id_token': refreshed})
          .refresh(accessToken: 'at', refreshToken: 'rt', idToken: loginIdToken);
      expect(bundle['idToken'], refreshed);
    });

    test('rejects a refreshed ID token with a bad signature', () {
      final forged =
          _sign(_claims(nonce: 'login-nonce'), key: _otherKey.privateKey);
      expect(
        refreshing({'access_token': 'at-2', 'id_token': forged}).refresh(
            accessToken: 'at', refreshToken: 'rt', idToken: loginIdToken),
        _rejected('bad signature'),
      );
    });

    test('rejects a refreshed ID token for another subject', () {
      final other = _sign({..._claims(nonce: 'login-nonce'), 'sub': 'user-2'});
      expect(
        refreshing({'access_token': 'at-2', 'id_token': other}).refresh(
            accessToken: 'at', refreshToken: 'rt', idToken: loginIdToken),
        _rejected('subject changed'),
      );
    });

    test('rejects a refreshed ID token with another nonce', () {
      final other = _sign(_claims(nonce: 'other-nonce'));
      expect(
        refreshing({'access_token': 'at-2', 'id_token': other}).refresh(
            accessToken: 'at', refreshToken: 'rt', idToken: loginIdToken),
        _rejected('nonce mismatch'),
      );
    });

    test('reports a 5xx without an OAuth error as a network failure', () {
      expect(
        refreshing({}, status: 503)
            .refresh(accessToken: 'at', refreshToken: 'rt'),
        throwsA(isA<CertiliaNetworkException>()
            .having((e) => e.statusCode, 'statusCode', 503)),
      );
    });
  });

  group('DirectAuthService profile', () {
    test('user and extended info come from the stored ID token', () async {
      final fake = _FakeCertilia((n) => _sign(_claims(nonce: n)));
      final bundle = await fake.login();
      final s = fake.service();
      final user = await s.fetchUserInfo('at', idToken: bundle['idToken'] as String);
      expect(user.lastName, 'Horvat');
      final info = await s.fetchExtendedInfo('at', idToken: bundle['idToken'] as String);
      expect(info!.email, 'ana@example.com');
      expect(info.availableFields, contains('given_name'));
    });

    test('without a stored ID token the user must log in again', () {
      final fake = _FakeCertilia((n) => '');
      expect(fake.service().fetchUserInfo('at'),
          throwsA(isA<CertiliaAuthenticationException>()));
    });
  });

  group('CertiliaConfig.direct', () {
    test('needs an https callbackUrl and no serverUrl', () {
      const CertiliaConfig(serverUrl: '', direct: _client, callbackUrl: _callback).validate();
      expect(
        () => const CertiliaConfig(serverUrl: '', direct: _client).validate(),
        throwsArgumentError,
      );
      expect(
        () => const CertiliaConfig(
          serverUrl: '',
          direct: _client,
          callbackUrl: 'hr.example.app:1/callback',
        ).validate(),
        throwsArgumentError,
      );
    });
  });
}
