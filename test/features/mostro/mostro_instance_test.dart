import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:test/test.dart';

NostrEvent _eventWithTags(List<List<String>> tags) => NostrEvent(
      id: 'a' * 64,
      kind: 38385,
      content: '',
      sig: 'b' * 128,
      pubkey: 'c' * 64,
      createdAt: DateTime(2026),
      tags: tags,
    );

void main() {
  group('MostroInstanceExtensions.bondPayoutClaimWindowDays', () {
    test('returns parsed int when tag is present', () {
      final event = _eventWithTags([
        ['bond_enabled', 'true'],
        ['bond_payout_claim_window_days', '15'],
      ]);
      expect(event.bondPayoutClaimWindowDays, 15);
    });

    test('returns null when tag is absent (older daemon)', () {
      // Pre-Phase-3 daemons omit all bond_* tags entirely. Must not throw.
      final event = _eventWithTags([
        ['mostro_version', '0.13.0'],
      ]);
      expect(event.bondPayoutClaimWindowDays, isNull);
    });
  });
}
