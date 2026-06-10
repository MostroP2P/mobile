import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/session.dart';

/// The maker anti-abuse bond keeps an uncommitted order ephemeral by marking
/// its session `bondPending`. That marker must never reach disk, or an
/// abandoned order would survive a restart. These pure tests lock that in.
void main() {
  final keyPair = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );

  Session makeSession() => Session(
        masterKey: keyPair,
        tradeKey: keyPair,
        keyIndex: 0,
        fullPrivacy: false,
        startTime: DateTime.parse('2026-06-03T12:00:00.000'),
        orderId: 'order-1',
      );

  group('Session.bondPending is transient', () {
    test('defaults to false', () {
      expect(makeSession().bondPending, isFalse);
    });

    test('is never written to disk (absent from toJson)', () {
      final session = makeSession()..bondPending = true;
      expect(session.toJson().containsKey('bond_pending'), isFalse);
    });

    test('is never restored from disk (always false after fromJson)', () {
      final json = {
        'master_key': keyPair,
        'trade_key': keyPair,
        'key_index': 0,
        'full_privacy': false,
        'start_time': '2026-06-03T12:00:00.000',
        'order_id': 'order-1',
        // Even if a stale/forged flag is present, it must be ignored.
        'bond_pending': true,
      };
      expect(Session.fromJson(json).bondPending, isFalse);
    });
  });
}
