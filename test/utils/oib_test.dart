import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_certilia/flutter_certilia.dart';
import 'package:flutter_certilia/src/utils/oib.dart';

// 12345678903 is a made-up number with a correct check digit.
const _validOib = '12345678903';

void main() {
  group('isValidOib', () {
    test('accepts a correct check digit', () {
      expect(isValidOib(_validOib), isTrue);
      expect(isValidOib('00000000001'), isTrue);
    });

    test('rejects a wrong check digit', () {
      expect(isValidOib('12345678901'), isFalse);
    });

    test('rejects wrong length and non-digits', () {
      expect(isValidOib('1234567890'), isFalse);
      expect(isValidOib('123456789033'), isFalse);
      expect(isValidOib('1234567890a'), isFalse);
      expect(isValidOib(''), isFalse);
    });
  });

  group('OIB from claims', () {
    test('CertiliaUser takes a valid OIB from sub', () {
      expect(CertiliaUser.fromJson({'sub': _validOib}).oib, _validOib);
    });

    test('a sub that is not an OIB leaves oib empty', () {
      expect(CertiliaUser.fromJson({'sub': '12345678901'}).oib, isNull);
      expect(CertiliaUser.fromJson({'sub': 'user-1'}).oib, isNull);
    });

    test('an explicit pin wins over sub', () {
      final user = CertiliaUser.fromJson({'sub': _validOib, 'pin': '00000000001'});
      expect(user.oib, '00000000001');
    });

    test('CertiliaExtendedInfo reads the same way', () {
      const info = CertiliaExtendedInfo(
        userInfo: {'sub': _validOib},
        availableFields: ['sub'],
      );
      expect(info.oib, _validOib);
    });
  });
}
