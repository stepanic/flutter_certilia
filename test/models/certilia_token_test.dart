import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_certilia/flutter_certilia.dart';

void main() {
  group('CertiliaToken.isExpired', () {
    test('returns false when expiresAt is null', () {
      const token = CertiliaToken(accessToken: 'at');
      expect(token.isExpired, isFalse);
    });

    test('returns false for a future expiry', () {
      final token = CertiliaToken(
        accessToken: 'at',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      expect(token.isExpired, isFalse);
    });

    test('returns true for a past expiry', () {
      final token = CertiliaToken(
        accessToken: 'at',
        expiresAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );
      expect(token.isExpired, isTrue);
    });
  });

  group('CertiliaToken.timeUntilExpiry', () {
    test('returns null when expiresAt is null', () {
      const token = CertiliaToken(accessToken: 'at');
      expect(token.timeUntilExpiry, isNull);
    });

    test('returns positive Duration when not yet expired', () {
      final token = CertiliaToken(
        accessToken: 'at',
        expiresAt: DateTime.now().add(const Duration(minutes: 30)),
      );
      final remaining = token.timeUntilExpiry!;
      expect(remaining.inMinutes, inInclusiveRange(28, 30));
    });

    test('returns Duration.zero when already expired', () {
      final token = CertiliaToken(
        accessToken: 'at',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      expect(token.timeUntilExpiry, Duration.zero);
    });
  });

  group('CertiliaToken JSON roundtrip', () {
    test('toJson/fromJson preserves all fields', () {
      final expiresAt = DateTime.fromMillisecondsSinceEpoch(
        // Trim sub-second precision since serialization is in seconds.
        (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
      );
      final original = CertiliaToken(
        accessToken: 'at-1',
        refreshToken: 'rt-1',
        idToken: 'id-1',
        expiresAt: expiresAt,
        tokenType: 'Bearer',
      );

      final restored = CertiliaToken.fromJson(original.toJson());
      expect(restored, equals(original));
    });

    test('fromJson handles expires_in (relative)', () {
      final before = DateTime.now();
      final token = CertiliaToken.fromJson({
        'access_token': 'at',
        'expires_in': 3600,
      });
      // Should be roughly an hour from now.
      final delta = token.expiresAt!.difference(before).inSeconds;
      expect(delta, inInclusiveRange(3595, 3605));
    });

    test('fromJson omits optional fields gracefully', () {
      final token = CertiliaToken.fromJson({'access_token': 'at'});
      expect(token.accessToken, 'at');
      expect(token.refreshToken, isNull);
      expect(token.idToken, isNull);
      expect(token.expiresAt, isNull);
      expect(token.tokenType, 'Bearer');
    });

    test('toJson omits null optional fields', () {
      const token = CertiliaToken(accessToken: 'at');
      final json = token.toJson();
      expect(json.containsKey('refresh_token'), isFalse);
      expect(json.containsKey('id_token'), isFalse);
      expect(json.containsKey('expires_at'), isFalse);
    });
  });

  group('CertiliaToken.copyWith', () {
    test('replaces only specified fields', () {
      const original = CertiliaToken(
        accessToken: 'at-1',
        refreshToken: 'rt-1',
      );
      final updated = original.copyWith(accessToken: 'at-2');
      expect(updated.accessToken, 'at-2');
      expect(updated.refreshToken, 'rt-1');
    });
  });
}
