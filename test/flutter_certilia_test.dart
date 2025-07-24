import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  group('flutter_certilia exports', () {
    test('exports are available', () {
      // Verify that all exports are available
      expect(CertiliaClient, isNotNull);
      expect(CertiliaConfig, isNotNull);
      expect(CertiliaUser, isNotNull);
      expect(CertiliaToken, isNotNull);
      expect(CertiliaException, isNotNull);
    });
  });
}