import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/src/utils/validators.dart';

void main() {
  group('Validators', () {
    group('isValidUrl', () {
      test('validates correct URLs', () {
        expect(Validators.isValidUrl('https://example.com'), isTrue);
        expect(Validators.isValidUrl('http://example.com'), isTrue);
        expect(Validators.isValidUrl('https://example.com/path'), isTrue);
        expect(Validators.isValidUrl('https://example.com:8080'), isTrue);
      });

      test('rejects invalid URLs', () {
        expect(Validators.isValidUrl(''), isFalse);
        expect(Validators.isValidUrl('not-a-url'), isFalse);
        expect(Validators.isValidUrl('ftp://example.com'), isFalse);
        expect(Validators.isValidUrl('example.com'), isFalse);
      });
    });

    group('isValidRedirectUrl', () {
      test('validates correct redirect URLs', () {
        expect(Validators.isValidRedirectUrl('https://example.com/callback'), isTrue);
        expect(Validators.isValidRedirectUrl('com.example.app://callback'), isTrue);
        expect(Validators.isValidRedirectUrl('myapp://auth'), isTrue);
      });

      test('rejects invalid redirect URLs', () {
        expect(Validators.isValidRedirectUrl(''), isFalse);
        expect(Validators.isValidRedirectUrl('no-scheme'), isFalse);
        expect(Validators.isValidRedirectUrl('://invalid'), isFalse);
      });
    });

    group('isValidOib', () {
      test('validates correct OIBs', () {
        // Valid test OIBs with correct checksum
        expect(Validators.isValidOib('00000000001'), isTrue);
        expect(Validators.isValidOib('69435151530'), isTrue); // Real valid test OIB
      });

      test('rejects invalid OIBs', () {
        expect(Validators.isValidOib(null), isFalse);
        expect(Validators.isValidOib(''), isFalse);
        expect(Validators.isValidOib('123'), isFalse);
        expect(Validators.isValidOib('12345678901'), isFalse); // Wrong checksum
        expect(Validators.isValidOib('abcdefghijk'), isFalse);
        expect(Validators.isValidOib('123456789012'), isFalse); // Too long
      });
    });

    group('isValidEmail', () {
      test('validates correct emails', () {
        expect(Validators.isValidEmail('user@example.com'), isTrue);
        expect(Validators.isValidEmail('user.name@example.com'), isTrue);
        expect(Validators.isValidEmail('user+tag@example.co.uk'), isTrue);
        expect(Validators.isValidEmail('user_123@example-domain.com'), isTrue);
      });

      test('rejects invalid emails', () {
        expect(Validators.isValidEmail(null), isFalse);
        expect(Validators.isValidEmail(''), isFalse);
        expect(Validators.isValidEmail('not-an-email'), isFalse);
        expect(Validators.isValidEmail('user@'), isFalse);
        expect(Validators.isValidEmail('@example.com'), isFalse);
        expect(Validators.isValidEmail('user@example'), isFalse);
        expect(Validators.isValidEmail('user @example.com'), isFalse);
      });
    });

    group('areValidScopes', () {
      test('validates correct scopes', () {
        expect(Validators.areValidScopes(['openid']), isTrue);
        expect(Validators.areValidScopes(['openid', 'profile', 'eid']), isTrue);
        expect(Validators.areValidScopes(['custom_scope']), isTrue);
      });

      test('rejects invalid scopes', () {
        expect(Validators.areValidScopes([]), isFalse);
        expect(Validators.areValidScopes(['']), isFalse);
        expect(Validators.areValidScopes(['scope with space']), isFalse);
        expect(Validators.areValidScopes(['valid', '']), isFalse);
        expect(Validators.areValidScopes(['valid', 'scope with space']), isFalse);
      });
    });
  });
}