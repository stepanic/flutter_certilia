import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/certilia_browser_client.dart';
import 'package:flutter_certilia/src/certilia_native_client.dart';
import 'package:flutter_certilia/src/services/certilia_logger.dart';
import 'package:flutter_certilia/src/services/proxy_auth_service.dart';

const _serverUrl = 'https://proxy.example';
const _customCallback = 'hr.example.app:1/callback';
const _httpsCallback = 'https://app.example/certilia/callback';

/// Fake proxy: answers /initialize with a fixed state and /exchange with a
/// token bundle, and records what the SDK sent.
class _FakeProxy {
  final requests = <http.Request>[];
  late final MockClient client = MockClient((request) async {
    requests.add(request);
    switch (request.url.path) {
      case '/api/auth/initialize':
        return http.Response(
          jsonEncode({
            'authorization_url': 'https://idp.example/oauth2/authorize?x=1',
            'state': 'state-1',
            'session_id': 'session-1',
          }),
          200,
        );
      case '/api/auth/exchange':
        return http.Response(
          jsonEncode({
            'accessToken': 'access',
            'refreshToken': 'refresh',
            'idToken': 'id',
            'expiresIn': 3600,
            'tokenType': 'Bearer',
            'user': {'sub': 'user-1'},
          }),
          200,
        );
    }
    return http.Response('not found', 404);
  });

  ProxyAuthService get service => ProxyAuthService(
        serverUrl: _serverUrl,
        logger: CertiliaLogger(componentName: 'test', enableLogging: false),
        httpClient: client,
      );
}

/// Records the launcher call and returns [result] (or throws [error]).
class _FakeLauncher {
  final String? result;
  final Object? error;
  String? url;
  String? scheme;
  FlutterWebAuth2Options? options;

  _FakeLauncher({this.result, this.error});

  Future<String> call({
    required String url,
    required String callbackUrlScheme,
    required FlutterWebAuth2Options options,
  }) async {
    this.url = url;
    scheme = callbackUrlScheme;
    this.options = options;
    if (error != null) throw error!;
    return result!;
  }
}

CertiliaBrowserClient _client(
  _FakeProxy proxy,
  _FakeLauncher launcher, {
  String callbackUrl = _customCallback,
}) =>
    CertiliaBrowserClient(
      config: CertiliaConfig(serverUrl: _serverUrl, callbackUrl: callbackUrl),
      serverUrl: _serverUrl,
      proxyService: proxy.service,
      launcher: launcher.call,
    );

Future<BuildContext> _context(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(Builder(builder: (c) {
    context = c;
    return const SizedBox();
  }));
  return context;
}

void main() {
  group('codeFromCallback', () {
    Uri cb(String query) => Uri.parse('$_customCallback?$query');

    test('returns the code when state matches', () {
      expect(codeFromCallback(cb('code=abc&state=s'), expectedState: 's'), 'abc');
    });

    test('null callback means the user cancelled', () {
      expect(
        () => codeFromCallback(null, expectedState: 's'),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.message, 'message', contains('cancelled'))),
      );
    });

    test('OAuth error is reported with its description', () {
      expect(
        () => codeFromCallback(
          cb('error=access_denied&error_description=User+denied&state=s'),
          expectedState: 's',
        ),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'access_denied')
            .having((e) => e.message, 'message', 'User denied')),
      );
    });

    test('state mismatch is rejected', () {
      expect(
        () => codeFromCallback(cb('code=abc&state=other'), expectedState: 's'),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'state_mismatch')),
      );
    });

    test('missing code is rejected', () {
      expect(
        () => codeFromCallback(cb('state=s'), expectedState: 's'),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'missing_code')),
      );
    });
  });

  group('CertiliaBrowserClient', () {
    test('requires a callbackUrl', () {
      expect(
        () => CertiliaBrowserClient(
          config: const CertiliaConfig(serverUrl: _serverUrl),
          serverUrl: _serverUrl,
        ),
        throwsArgumentError,
      );
    });

    testWidgets('custom scheme: initialize, launch, exchange', (tester) async {
      final proxy = _FakeProxy();
      final launcher = _FakeLauncher(
        result: '$_customCallback?code=the-code&state=state-1&session_state=x',
      );

      final context = await _context(tester);
      final tokens = await _client(proxy, launcher).authenticate(context);

      final init = proxy.requests.first;
      expect(init.url.queryParameters['redirect_uri'], _customCallback);
      expect(launcher.url, 'https://idp.example/oauth2/authorize?x=1');
      expect(launcher.scheme, 'hr.example.app');
      expect(launcher.options!.httpsHost, isNull);

      final exchange = proxy.requests.last;
      expect(exchange.url.path, '/api/auth/exchange');
      expect(jsonDecode(exchange.body), {
        'code': 'the-code',
        'state': 'state-1',
        'session_id': 'session-1',
      });
      expect(tokens['accessToken'], 'access');
      expect(tokens['user'], {'sub': 'user-1'});
    });

    testWidgets('https callback passes host and path for App Links',
        (tester) async {
      final proxy = _FakeProxy();
      final launcher = _FakeLauncher(
        result: '$_httpsCallback?code=c&state=state-1',
      );

      final context = await _context(tester);
      await _client(proxy, launcher, callbackUrl: _httpsCallback)
          .authenticate(context);

      expect(launcher.scheme, 'https');
      expect(launcher.options!.httpsHost, 'app.example');
      expect(launcher.options!.httpsPath, '/certilia/callback');
    });

    testWidgets('closing the browser reports a cancellation', (tester) async {
      final proxy = _FakeProxy();
      final launcher = _FakeLauncher(
        error: PlatformException(code: 'CANCELED'),
      );

      final context = await _context(tester);
      await expectLater(
        _client(proxy, launcher).authenticate(context),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.message, 'message', contains('cancelled'))),
      );
      expect(proxy.requests.map((r) => r.url.path),
          isNot(contains('/api/auth/exchange')));
    });

    testWidgets('a forged state never reaches the exchange', (tester) async {
      final proxy = _FakeProxy();
      final launcher = _FakeLauncher(
        result: '$_customCallback?code=c&state=attacker',
      );

      final context = await _context(tester);
      await expectLater(
        _client(proxy, launcher).authenticate(context),
        throwsA(isA<CertiliaAuthenticationException>()
            .having((e) => e.code, 'code', 'state_mismatch')),
      );
      expect(proxy.requests.map((r) => r.url.path),
          isNot(contains('/api/auth/exchange')));
    });
  });

  group('CertiliaConfig.callbackUrl', () {
    test('accepts https and custom schemes', () {
      const CertiliaConfig(serverUrl: _serverUrl, callbackUrl: _httpsCallback)
          .validate();
      const CertiliaConfig(serverUrl: _serverUrl, callbackUrl: _customCallback)
          .validate();
    });

    test('rejects plain http outside localhost', () {
      expect(
        () => const CertiliaConfig(
          serverUrl: _serverUrl,
          callbackUrl: 'http://app.example/cb',
        ).validate(),
        throwsArgumentError,
      );
    });

    test('rejects a relative URL', () {
      expect(
        () => const CertiliaConfig(serverUrl: _serverUrl, callbackUrl: '/cb')
            .validate(),
        throwsArgumentError,
      );
    });
  });
}
