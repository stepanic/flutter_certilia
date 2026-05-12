import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  group('flutter_certilia exports', () {
    test('public API is exported', () {
      expect(CertiliaSDK, isNotNull);
      expect(CertiliaConfig, isNotNull);
      expect(CertiliaUser, isNotNull);
      expect(CertiliaToken, isNotNull);
      expect(CertiliaExtendedInfo, isNotNull);
      expect(CertiliaException, isNotNull);
    });
  });
}
