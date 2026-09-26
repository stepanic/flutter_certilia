import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/certilia_native_client.dart';
import 'package:flutter_certilia/src/certilia_stateful_wrapper.dart';
import 'package:flutter_certilia/src/services/certilia_auth_backend.dart';
import 'package:flutter_certilia/src/services/token_storage_service.dart';

const _config = CertiliaConfig(serverUrl: 'https://proxy.example');

/// Backend whose refresh fails the way Certilia's does for portal clients.
class _RefusingBackend implements CertiliaAuthBackend {
  int refreshCalls = 0;

  @override
  Future<Map<String, dynamic>> refresh({
    required String accessToken,
    required String refreshToken,
  }) async {
    refreshCalls++;
    throw const CertiliaAuthenticationException(
      message: 'Persisted access token data not found',
      code: 'invalid_grant',
    );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
