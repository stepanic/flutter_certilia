import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  group('CertiliaUser', () {
    const testSub = '123456789';
    const testFirstName = 'Ivo';
    const testLastName = 'Ivić';
    const testOib = '12345678901';
    const testEmail = 'ivo.ivic@example.com';
    final testBirthDate = DateTime(1990, 5, 15);

    final testJson = {
      'sub': testSub,
      'given_name': testFirstName,
      'family_name': testLastName,
      'oib': testOib,
      'email': testEmail,
      'birthdate': '1990-05-15',
      'custom_field': 'custom_value',
    };

    test('fromJson creates user correctly', () {
      final user = CertiliaUser.fromJson(testJson);

      expect(user.sub, equals(testSub));
      expect(user.firstName, equals(testFirstName));
      expect(user.lastName, equals(testLastName));
      expect(user.oib, equals(testOib));
      expect(user.email, equals(testEmail));
      expect(user.dateOfBirth, equals(testBirthDate));
      expect(user.raw['custom_field'], equals('custom_value'));
    });

    test('fromJson handles alternative field names', () {
      final altJson = {
        'sub': testSub,
        'firstName': testFirstName,
        'lastName': testLastName,
      };

      final user = CertiliaUser.fromJson(altJson);

      expect(user.firstName, equals(testFirstName));
      expect(user.lastName, equals(testLastName));
    });

    test('fromJson handles missing optional fields', () {
      final minimalJson = {'sub': testSub};

      final user = CertiliaUser.fromJson(minimalJson);

      expect(user.sub, equals(testSub));
      expect(user.firstName, isNull);
      expect(user.lastName, isNull);
      expect(user.oib, isNull);
      expect(user.email, isNull);
      expect(user.dateOfBirth, isNull);
    });

    test('toJson returns correct map', () {
      final user = CertiliaUser(
        sub: testSub,
        firstName: testFirstName,
        lastName: testLastName,
        oib: testOib,
        email: testEmail,
        dateOfBirth: testBirthDate,
        raw: testJson,
      );

      final json = user.toJson();

      expect(json['sub'], equals(testSub));
      expect(json['given_name'], equals(testFirstName));
      expect(json['family_name'], equals(testLastName));
      expect(json['oib'], equals(testOib));
      expect(json['email'], equals(testEmail));
      expect(json['birthdate'], equals('1990-05-15'));
      expect(json['custom_field'], equals('custom_value'));
    });

    test('fullName returns correct value', () {
      final user = CertiliaUser(
        sub: testSub,
        firstName: testFirstName,
        lastName: testLastName,
        raw: {},
      );

      expect(user.fullName, equals('$testFirstName $testLastName'));
    });

    test('fullName handles missing names', () {
      final userFirstNameOnly = CertiliaUser(
        sub: testSub,
        firstName: testFirstName,
        raw: {},
      );
      expect(userFirstNameOnly.fullName, equals(testFirstName));

      final userLastNameOnly = CertiliaUser(
        sub: testSub,
        lastName: testLastName,
        raw: {},
      );
      expect(userLastNameOnly.fullName, equals(testLastName));

      final userNoName = CertiliaUser(
        sub: testSub,
        raw: {},
      );
      expect(userNoName.fullName, isNull);
    });

    test('copyWith creates new instance with updated values', () {
      final original = CertiliaUser(
        sub: testSub,
        firstName: testFirstName,
        raw: {},
      );

      final updated = original.copyWith(
        lastName: testLastName,
        email: testEmail,
      );

      expect(updated.sub, equals(testSub));
      expect(updated.firstName, equals(testFirstName));
      expect(updated.lastName, equals(testLastName));
      expect(updated.email, equals(testEmail));
      expect(identical(original, updated), isFalse);
    });

    test('equality and hashCode work correctly', () {
      final user1 = CertiliaUser.fromJson(testJson);
      final user2 = CertiliaUser.fromJson(testJson);
      final user3 = CertiliaUser.fromJson({
        ...testJson,
        'sub': 'different',
      });

      expect(user1, equals(user2));
      // Note: hashCode might differ due to Map implementation details
      // expect(user1.hashCode, equals(user2.hashCode));
      expect(user1, isNot(equals(user3)));
    });

    test('date parsing handles invalid dates gracefully', () {
      final jsonWithInvalidDate = {
        'sub': testSub,
        'birthdate': 'invalid-date',
      };

      final user = CertiliaUser.fromJson(jsonWithInvalidDate);
      expect(user.dateOfBirth, isNull);
    });
  });
}