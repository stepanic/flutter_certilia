import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/certilia_native_client.dart';
import 'package:flutter_certilia/src/certilia_stateful_wrapper.dart';
import 'package:flutter_certilia/src/services/certilia_auth_backend.dart';
import 'package:flutter_certilia/src/services/token_storage_service.dart';

const _config = CertiliaConfig(serverUrl: 'https://proxy.example');

/// Backend whose refresh fails with [error]; by default the way Certilia's
/// does for portal clients.
class _RefusingBackend implements CertiliaAuthBackend {
  final Object error;
  int refreshCalls = 0;

  _RefusingBackend([
    this.error = const CertiliaAuthenticationException(
      message: 'Persisted access token data not found',
      code: 'invalid_grant',
    ),
  ]);

  @override
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
    String? idToken,
  }) async {
    refreshCalls++;
    throw error;
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Backend whose refresh returns only a new access token.
class _AccessTokenOnlyBackend implements CertiliaAuthBackend {
  String? idTokenSeen;

  @override
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
    String? idToken,
  }) async {
    idTokenSeen = idToken;
    return {'accessToken': 'at-2', 'expiresIn': 3600};
  }

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _Client extends CertiliaNativeClient {
  _Client(CertiliaAuthBackend backend)
      : super(
          config: _config,
          serverUrl: _config.serverUrl,
          componentName: 'test',
          backend: backend,
        );

  @override
  String get redirectUri => 'https://app.example/cb';

  @override
  Future<Uri?> obtainCallback(BuildContext context, String authorizationUrl) =>
      throw UnimplementedError();
}

Future<TokenStorageService> _storedExpiredSession() async {
  FlutterSecureStorage.setMockInitialValues({});
  final tokens = TokenStorageService(storage: const FlutterSecureStorage());
  await tokens.saveToken(CertiliaToken(
    accessToken: 'at',
    refreshToken: 'rt',
    idToken: 'id-token',
    expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
  ));
  return tokens;
}

CertiliaStatefulWrapper _wrapper(
        TokenStorageService tokens, CertiliaAuthBackend backend) =>
    CertiliaStatefulWrapper(
      config: _config,
      serverUrl: _config.serverUrl,
      storage: const FlutterSecureStorage(),
      tokenStorage: tokens,
      client: _Client(backend),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final error in [
    const CertiliaNetworkException(message: 'timed out', statusCode: 408),
    const CertiliaNetworkException(message: 'bad gateway', statusCode: 502),
    Exception('connection reset'),
  ]) {
    test('a refresh that fails with $error keeps the session', () async {
      final tokens = await _storedExpiredSession();
      final wrapper = _wrapper(tokens, _RefusingBackend(error));

      await expectLater(
          wrapper.getCurrentUser(), throwsA(isA<CertiliaException>()));
      expect((await tokens.loadToken())?.refreshToken, 'rt');
    });
  }

  test('a refresh the proxy answers with 401 ends the session', () async {
    final tokens = await _storedExpiredSession();
    final wrapper = _wrapper(
      tokens,
      _RefusingBackend(const CertiliaNetworkException(
          message: 'Token refresh failed', statusCode: 401)),
    );

    expect(await wrapper.getCurrentUser(), isNull);
    expect(await tokens.loadToken(), isNull);
  });

  test('a refresh without a new ID token keeps the stored one', () async {
    final tokens = await _storedExpiredSession();
    final backend = _AccessTokenOnlyBackend();
    final wrapper = _wrapper(tokens, backend);
    await wrapper.checkAuthenticationStatus();

    await wrapper.refreshToken();

    expect(backend.idTokenSeen, 'id-token');
    expect(wrapper.currentAccessToken, 'at-2');
    expect(wrapper.currentIdToken, 'id-token');
    expect((await tokens.loadToken())!.idToken, 'id-token');
  });

  test('an expired session whose refresh fails is logged out, not thrown',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = FlutterSecureStorage();
    final tokens = TokenStorageService(storage: storage);
    await tokens.saveToken(CertiliaToken(
      accessToken: 'at',
      refreshToken: 'rt',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
    ));

    final backend = _RefusingBackend();
    final wrapper = CertiliaStatefulWrapper(
      config: _config,
      serverUrl: _config.serverUrl,
      storage: storage,
      tokenStorage: tokens,
      client: _Client(backend),
    );

    expect(await wrapper.getCurrentUser(), isNull);
    expect(backend.refreshCalls, 1);
    expect(await tokens.loadToken(), isNull);
    expect(await wrapper.checkAuthenticationStatus(), isFalse);
  });
}
