import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  group('CertiliaConfig.validate', () {
    test('accepts a well-formed config', () {
      const config = CertiliaConfig(serverUrl: 'https://proxy.example');
      expect(config.validate, returnsNormally);
    });

    test('rejects empty serverUrl', () {
      const config = CertiliaConfig(serverUrl: '');
      expect(config.validate, throwsA(isA<ArgumentError>()));
    });

    test('rejects non-HTTP scheme', () {
      const config = CertiliaConfig(serverUrl: 'ws://proxy.example');
      expect(config.validate, throwsA(isA<ArgumentError>()));
    });

    test('rejects empty scopes', () {
      const config = CertiliaConfig(
        serverUrl: 'https://proxy.example',
        scopes: [],
      );
      expect(config.validate, throwsA(isA<ArgumentError>()));
    });

    test('accepts http (not just https) for local dev', () {
      const config = CertiliaConfig(serverUrl: 'http://localhost:3000');
      expect(config.validate, returnsNormally);
    });
  });

  group('CertiliaConfig equality', () {
    test('equal configs are ==', () {
      const a = CertiliaConfig(serverUrl: 'https://proxy.example');
      const b = CertiliaConfig(serverUrl: 'https://proxy.example');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('different serverUrl breaks equality', () {
      const a = CertiliaConfig(serverUrl: 'https://a.example');
      const b = CertiliaConfig(serverUrl: 'https://b.example');
      expect(a, isNot(equals(b)));
    });
  });
}
