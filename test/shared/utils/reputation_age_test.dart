import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/reputation_age.dart';

void main() {
  // 2023-11-14T00:00:00Z, a UTC day boundary as mostrod publishes it.
  const since = 1699920000;
  final firstDay = DateTime.utc(2023, 11, 14);

  group('reputationDaysOnMostro', () {
    test('counts whole days from since to now', () {
      final now = firstDay.add(const Duration(days: 64, hours: 5));

      expect(
        reputationDaysOnMostro(since: since, fallbackDays: 3, now: now),
        64,
      );
    });

    test('gives 0 on the day of the first trade', () {
      final now = firstDay.add(const Duration(hours: 23, minutes: 59));

      expect(
        reputationDaysOnMostro(since: since, fallbackDays: 3, now: now),
        0,
      );
    });

    test('falls back to the published day count without since', () {
      expect(
        reputationDaysOnMostro(since: null, fallbackDays: 30, now: firstDay),
        30,
      );
    });

    test('clamps a since in the future to 0', () {
      final now = firstDay.subtract(const Duration(days: 2));

      expect(
        reputationDaysOnMostro(since: since, fallbackDays: 3, now: now),
        0,
      );
    });
  });

  group('parseReputationSince', () {
    test('accepts a positive integer', () {
      expect(parseReputationSince(since), since);
    });

    test('rejects absent, zero and negative values', () {
      expect(parseReputationSince(null), isNull);
      expect(parseReputationSince(0), isNull);
      expect(parseReputationSince(-86400), isNull);
    });

    test('rejects strings and fractional numbers', () {
      expect(parseReputationSince('1699920000'), isNull);
      expect(parseReputationSince(1699920000.5), isNull);
    });

    test('rejects a value past the last date DateTime can hold', () {
      expect(parseReputationSince(8640000000000), 8640000000000);
      expect(parseReputationSince(8640000000001), isNull);
    });
  });
}
