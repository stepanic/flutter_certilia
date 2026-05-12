import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/services/certilia_logger.dart';
import 'package:flutter_certilia/src/services/proxy_auth_service.dart';

const _serverUrl = 'https://proxy.example';

ProxyAuthService _service(MockClient client) => ProxyAuthService(
      serverUrl: _serverUrl,
      logger: CertiliaLogger(componentName: 'test', enableLogging: false),
      httpClient: client,
    );

void main() {
  group('ProxyAuthService.initialize', () {
    test('returns parsed JSON on 200', () async {
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/auth/initialize');
        expect(request.url.queryParameters['response_type'], 'code');
        expect(
          request.url.queryParameters['redirect_uri'],
          '$_serverUrl/api/auth/callback',
        );
        return http.Response(
          jsonEncode({
            'authorization_url': 'https://idp.test.certilia.com/oauth2/auth',
            'state': 'st-123',
            'session_id': 'sess-1',
          }),
          200,
        );
      });

      final data = await _service(client).initialize();
      expect(data['state'], 'st-123');
      expect(data['session_id'], 'sess-1');
    });

    test('throws CertiliaNetworkException on non-200', () async {
      final client = MockClient((_) async => http.Response('boom', 500));
      await expectLater(
        _service(client).initialize(),
        throwsA(isA<CertiliaNetworkException>()
            .having((e) => e.statusCode, 'statusCode', 500)),
      );
    });
  });

  group('ProxyAuthService.exchange', () {
    test('returns tokens on first-try 200', () async {
      var attempts = 0;
      final client = MockClient((request) async {
        attempts++;
        expect(request.url.path, '/api/auth/exchange');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['code'], 'auth-code');
        expect(body['state'], 'st-123');
        expect(body['session_id'], 'sess-1');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-1',
            'refreshToken': 'rt-1',
            'expiresIn': 3600,
          }),
          200,
        );
      });

      final result = await _service(client).exchange(
        code: 'auth-code',
        state: 'st-123',
        sessionId: 'sess-1',
      );
      expect(attempts, 1);
      expect(result['accessToken'], 'at-1');
    });

    test('does not retry on terminal non-408 server error', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        return http.Response('bad request', 400);
      });

      await expectLater(
        _service(client).exchange(
          code: 'c',
          state: 's',
          sessionId: 'sid',
        ),
        throwsA(isA<CertiliaNetworkException>()
            .having((e) => e.statusCode, 'statusCode', 400)),
      );
      expect(attempts, 1, reason: 'must not retry a 400');
    });

    test('retries on transient failure and succeeds', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        if (attempts < 2) {
          throw http.ClientException('network down');
        }
        return http.Response(
          jsonEncode({'accessToken': 'at-recovered'}),
          200,
        );
      });

      final result = await _service(client).exchange(
        code: 'c',
        state: 's',
        sessionId: 'sid',
      );
      expect(result['accessToken'], 'at-recovered');
      expect(attempts, 2);
    }, timeout: const Timeout(Duration(seconds: 10)));

    test('throws after exhausting retries', () async {
      var attempts = 0;
      final client = MockClient((_) async {
        attempts++;
        throw http.ClientException('still down');
      });

      await expectLater(
        _service(client).exchange(
          code: 'c',
          state: 's',
          sessionId: 'sid',
        ),
        throwsA(isA<Exception>()),
      );
      expect(attempts, 3, reason: 'expected three attempts');
    }, timeout: const Timeout(Duration(seconds: 10)));
  });

  group('ProxyAuthService.refresh', () {
    test('sends both tokens in body, no Authorization header', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/refresh');
        expect(
          request.headers['Authorization'],
          isNull,
          reason: 'refresh must not use Bearer auth (Phase 2B)',
        );
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['refresh_token'], 'rt-original');
        expect(body['access_token'], 'at-original');
        return http.Response(
          jsonEncode({
            'accessToken': 'at-new',
            'refreshToken': 'rt-new',
            'expiresIn': 3600,
          }),
          200,
        );
      });

      final result = await _service(client).refresh(
        accessToken: 'at-original',
        refreshToken: 'rt-original',
      );
      expect(result['accessToken'], 'at-new');
      expect(result['refreshToken'], 'rt-new');
    });

    test('throws on server error', () async {
      final client = MockClient(
        (_) async => http.Response('unauthorized', 401),
      );
      await expectLater(
        _service(client).refresh(accessToken: 'a', refreshToken: 'r'),
        throwsA(isA<CertiliaNetworkException>()
            .having((e) => e.statusCode, 'statusCode', 401)),
      );
    });
  });

  group('ProxyAuthService.fetchUserInfo', () {
    test('parses user from `user` envelope', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/user');
        expect(request.headers['Authorization'], 'Bearer at-1');
        return http.Response(
          jsonEncode({
            'user': {
              'sub': 'user-1',
              'given_name': 'Ana',
              'family_name': 'Anic',
            },
          }),
          200,
        );
      });

      final user = await _service(client).fetchUserInfo('at-1');
      expect(user.sub, 'user-1');
      expect(user.firstName, 'Ana');
      expect(user.lastName, 'Anic');
    });

    test('throws on non-200', () async {
      final client =
          MockClient((_) async => http.Response('forbidden', 403));
      await expectLater(
        _service(client).fetchUserInfo('at-1'),
        throwsA(isA<CertiliaNetworkException>()),
      );
    });
  });

  group('ProxyAuthService.fetchExtendedInfo', () {
    test('returns parsed info on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/user/extended-info');
        return http.Response(
          jsonEncode({
            'available_fields': ['sub', 'oib'],
            'user_info': {
              'sub': 'u-1',
              'oib': '12345678901',
            },
          }),
          200,
        );
      });

      final info = await _service(client).fetchExtendedInfo('at-1');
      expect(info, isNotNull);
      expect(info!.oib, '12345678901');
      expect(info.availableFields, ['sub', 'oib']);
    });

    test('returns null on 401 so caller can refresh and retry', () async {
      final client =
          MockClient((_) async => http.Response('expired', 401));
      expect(await _service(client).fetchExtendedInfo('at-1'), isNull);
    });

    test('returns null on 502 (upstream Certilia hiccup)', () async {
      final client =
          MockClient((_) async => http.Response('bad gateway', 502));
      expect(await _service(client).fetchExtendedInfo('at-1'), isNull);
    });

    test('throws on other non-200 statuses', () async {
      final client =
          MockClient((_) async => http.Response('teapot', 418));
      await expectLater(
        _service(client).fetchExtendedInfo('at-1'),
        throwsA(isA<CertiliaNetworkException>()),
      );
    });
  });

  group('ProxyAuthService.pollStatus', () {
    test('returns parsed body on 200', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/polling/poll-1/status');
        return http.Response(
          jsonEncode({
            'status': 'completed',
            'result': {'code': 'auth-code'},
          }),
          200,
        );
      });
      final data = await _service(client).pollStatus('poll-1');
      expect(data, isNotNull);
      expect(data!['status'], 'completed');
    });

    test('returns null on 404 (expired session)', () async {
      final client =
          MockClient((_) async => http.Response('gone', 404));
      expect(await _service(client).pollStatus('poll-1'), isNull);
    });

    test('throws on other non-200', () async {
      final client =
          MockClient((_) async => http.Response('oops', 500));
      await expectLater(
        _service(client).pollStatus('poll-1'),
        throwsA(isA<CertiliaNetworkException>()),
      );
    });
  });

  group('ProxyAuthService.startPollingSession', () {
    test('posts state + session_id, returns polling_id', () async {
      final client = MockClient((request) async {
        expect(request.url.path, '/api/auth/polling/start');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['state'], 'st-1');
        expect(body['session_id'], 'sess-1');
        return http.Response(
          jsonEncode({'polling_id': 'poll-xyz'}),
          200,
        );
      });

      final data = await _service(client).startPollingSession(
        state: 'st-1',
        sessionId: 'sess-1',
      );
      expect(data['polling_id'], 'poll-xyz');
    });
  });
}
