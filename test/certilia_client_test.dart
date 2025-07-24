import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

@GenerateMocks([FlutterAppAuth, FlutterSecureStorage, http.Client])
import 'certilia_client_test.mocks.dart';

void main() {
  late MockFlutterAppAuth mockAppAuth;
  late MockFlutterSecureStorage mockSecureStorage;
  late MockClient mockHttpClient;
  late CertiliaConfig config;
  late CertiliaClient client;

  setUp(() {
    mockAppAuth = MockFlutterAppAuth();
    mockSecureStorage = MockFlutterSecureStorage();
    mockHttpClient = MockClient();
    
    config = const CertiliaConfig(
      clientId: 'test_client_id',
      redirectUrl: 'com.example.app://callback',
    );
    
    client = CertiliaClient(
      config: config,
      appAuth: mockAppAuth,
      secureStorage: mockSecureStorage,
      httpClient: mockHttpClient,
    );
  });

  group('CertiliaClient', () {
    test('constructor validates config', () {
      expect(
        () => CertiliaClient(
          config: const CertiliaConfig(
            clientId: '',
            redirectUrl: 'com.example.app://callback',
          ),
        ),
        throwsArgumentError,
      );
    });

    group('authenticate', () {
      test('successful authentication returns user', () async {
        // Mock successful auth response
        final authResult = AuthorizationTokenResponse(
          'test_access_token',
          'test_refresh_token',
          DateTime.now().add(const Duration(hours: 1)),
          'test_id_token',
          'Bearer',
          null, // authorizationAdditionalParameters
          <String, String>{}, // tokenAdditionalParameters
          null, // scopes
        );
        
        when(mockAppAuth.authorizeAndExchangeCode(any))
            .thenAnswer((_) async => authResult);
        
        // Mock user info response
        final userJson = {
          'sub': '123456',
          'given_name': 'Test',
          'family_name': 'User',
          'oib': '00000000001',
        };
        
        when(mockHttpClient.get(
          any,
          headers: anyNamed('headers'),
        )).thenAnswer((_) async => http.Response(jsonEncode(userJson), 200));
        
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});
        
        // Test authentication
        final user = await client.authenticate();
        
        expect(user.sub, equals('123456'));
        expect(user.firstName, equals('Test'));
        expect(user.lastName, equals('User'));
        expect(user.oib, equals('00000000001'));
        
        // Verify calls
        verify(mockAppAuth.authorizeAndExchangeCode(any)).called(1);
        verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(1);
        verify(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value'))).called(1);
      });

      // TODO: Fix this test - mockito doesn't support returning null for non-nullable types
      // test('cancelled authentication throws exception', () async {
      //   when(mockAppAuth.authorizeAndExchangeCode(any))
      //       .thenAnswer((_) async => null);
      //   
      //   expect(
      //     () => client.authenticate(),
      //     throwsA(isA<CertiliaAuthenticationException>()),
      //   );
      // });

      test('network error throws exception', () async {
        final authResult = AuthorizationTokenResponse(
          'test_access_token',
          null,
          DateTime.now().add(const Duration(hours: 1)),
          null,
          'Bearer',
          null, // authorizationAdditionalParameters
          <String, String>{}, // tokenAdditionalParameters
          null, // scopes
        );
        
        when(mockAppAuth.authorizeAndExchangeCode(any))
            .thenAnswer((_) async => authResult);
        
        when(mockHttpClient.get(any, headers: anyNamed('headers')))
            .thenAnswer((_) async => http.Response('Error', 401));
        
        when(mockSecureStorage.write(key: anyNamed('key'), value: anyNamed('value')))
            .thenAnswer((_) async {});
        
        expect(
          () => client.authenticate(),
          throwsA(isA<CertiliaNetworkException>()),
        );
      });
    });

    group('isAuthenticated', () {
      test('returns false when no token', () {
        expect(client.isAuthenticated, isFalse);
      });
    });

    group('logout', () {
      test('clears token from storage', () async {
        when(mockSecureStorage.delete(key: anyNamed('key')))
            .thenAnswer((_) async {});
        
        await client.logout();
        
        verify(mockSecureStorage.delete(key: 'certilia_token')).called(1);
        expect(client.isAuthenticated, isFalse);
      });
    });
  });

  group('CertiliaConfig', () {
    test('validates required fields', () {
      const validConfig = CertiliaConfig(
        clientId: 'test',
        redirectUrl: 'https://example.com',
      );
      
      expect(() => validConfig.validate(), returnsNormally);
      
      const invalidConfig1 = CertiliaConfig(
        clientId: '',
        redirectUrl: 'https://example.com',
      );
      
      expect(() => invalidConfig1.validate(), throwsArgumentError);
      
      const invalidConfig2 = CertiliaConfig(
        clientId: 'test',
        redirectUrl: '',
      );
      
      expect(() => invalidConfig2.validate(), throwsArgumentError);
    });

    test('copyWith creates new instance', () {
      const original = CertiliaConfig(
        clientId: 'test',
        redirectUrl: 'https://example.com',
      );
      
      final updated = original.copyWith(
        clientId: 'new_test',
        enableLogging: true,
      );
      
      expect(updated.clientId, equals('new_test'));
      expect(updated.redirectUrl, equals('https://example.com'));
      expect(updated.enableLogging, isTrue);
      expect(identical(original, updated), isFalse);
    });
  });

  group('CertiliaToken', () {
    test('isExpired returns correct value', () {
      final expiredToken = CertiliaToken(
        accessToken: 'test',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      
      expect(expiredToken.isExpired, isTrue);
      
      final validToken = CertiliaToken(
        accessToken: 'test',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      
      expect(validToken.isExpired, isFalse);
      
      const noExpiryToken = CertiliaToken(
        accessToken: 'test',
      );
      
      expect(noExpiryToken.isExpired, isFalse);
    });

    test('fromJson handles expires_in', () {
      final json = {
        'access_token': 'test_token',
        'refresh_token': 'refresh_token',
        'expires_in': 3600,
        'token_type': 'Bearer',
      };
      
      final token = CertiliaToken.fromJson(json);
      
      expect(token.accessToken, equals('test_token'));
      expect(token.refreshToken, equals('refresh_token'));
      expect(token.tokenType, equals('Bearer'));
      expect(token.expiresAt, isNotNull);
      expect(
        token.expiresAt!.isAfter(DateTime.now()),
        isTrue,
      );
    });
  });
}