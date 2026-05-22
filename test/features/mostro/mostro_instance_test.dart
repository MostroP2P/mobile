import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';

void main() {
  group('MostroInstance anti-abuse bond tags', () {
    NostrEvent buildEvent(List<List<String>> extraTags) {
      return NostrEvent(
        id: 'a' * 64,
        kind: 38385,
        content: '',
        sig: 'b' * 128,
        pubkey: 'c' * 64,
        createdAt: DateTime(2025),
        tags: [
          ['d', 'c' * 64],
          ['mostro_version', '0.13.0'],
          ['mostro_commit_hash', 'deadbeef'],
          ['max_order_amount', '1000000'],
          ['min_order_amount', '1'],
          ['expiration_hours', '24'],
          ['expiration_seconds', '900'],
          ['fee', '0.006'],
          ['pow', '0'],
          ['hold_invoice_expiration_window', '300'],
          ['hold_invoice_cltv_delta', '144'],
          ['invoice_expiration_window', '300'],
          ['lnd_version', '0.18.0'],
          ['lnd_node_pubkey', 'd' * 66],
          ['lnd_commit_hash', 'cafebabe'],
          ['lnd_node_alias', 'mostro-lnd'],
          ['lnd_chains', 'bitcoin'],
          ['lnd_networks', 'mainnet'],
          ['lnd_uris', 'lnd://example'],
          ['fiat_currencies_accepted', 'USD,EUR'],
          ['max_orders_per_response', '100'],
          ...extraTags,
        ],
      );
    }

    test('legacy daemon: bond_enabled tag absent → BondPolicy.unsupported', () {
      final event = buildEvent(const []);
      final instance = MostroInstance.fromEvent(event);

      expect(instance.bondPolicy, BondPolicy.unsupported);
      expect(instance.bondApplyTo, isNull);
      expect(instance.bondSlashOnWaitingTimeout, isNull);
      expect(instance.bondAmountPct, isNull);
      expect(instance.bondBaseAmountSats, isNull);
      expect(instance.bondSlashNodeSharePct, isNull);
      expect(instance.bondPayoutClaimWindowDays, isNull);
    });

    test('modern daemon, feature off: bond_enabled="false" → BondPolicy.disabled', () {
      final event = buildEvent(const [
        ['bond_enabled', 'false'],
      ]);
      final instance = MostroInstance.fromEvent(event);

      expect(instance.bondPolicy, BondPolicy.disabled);
      expect(instance.bondApplyTo, isNull);
      expect(instance.bondSlashOnWaitingTimeout, isNull);
      expect(instance.bondAmountPct, isNull);
      expect(instance.bondBaseAmountSats, isNull);
      expect(instance.bondSlashNodeSharePct, isNull);
      expect(instance.bondPayoutClaimWindowDays, isNull);
    });

    test('bond active: bond_enabled="true" with all six bond parameters', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_apply_to', 'both'],
        ['bond_slash_on_waiting_timeout', 'true'],
        ['bond_amount_pct', '0.01'],
        ['bond_base_amount_sats', '1000'],
        ['bond_slash_node_share_pct', '0.5'],
        ['bond_payout_claim_window_days', '15'],
      ]);
      final instance = MostroInstance.fromEvent(event);

      expect(instance.bondPolicy, BondPolicy.enabled);
      expect(instance.bondApplyTo, BondApplyTo.both);
      expect(instance.bondSlashOnWaitingTimeout, isTrue);
      expect(instance.bondAmountPct, 0.01);
      expect(instance.bondBaseAmountSats, 1000);
      expect(instance.bondSlashNodeSharePct, 0.5);
      expect(instance.bondPayoutClaimWindowDays, 15);
    });

    test('bond_apply_to enum: all three values parse correctly', () {
      for (final entry in {
        'take': BondApplyTo.take,
        'make': BondApplyTo.make,
        'both': BondApplyTo.both,
      }.entries) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_apply_to', entry.key],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondApplyTo, entry.value, reason: entry.key);
      }
    });

    test('bond_apply_to with unknown value → null (defensive)', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_apply_to', 'unexpected'],
      ]);
      final instance = MostroInstance.fromEvent(event);
      expect(instance.bondApplyTo, isNull);
    });

    test('numeric bond tags with malformed values → null (defensive)', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_amount_pct', 'not-a-number'],
        ['bond_base_amount_sats', 'NaN'],
        ['bond_slash_node_share_pct', ''],
        ['bond_payout_claim_window_days', 'fifteen'],
      ]);
      final instance = MostroInstance.fromEvent(event);

      expect(instance.bondPolicy, BondPolicy.enabled);
      expect(instance.bondAmountPct, isNull);
      expect(instance.bondBaseAmountSats, isNull);
      expect(instance.bondSlashNodeSharePct, isNull);
      expect(instance.bondPayoutClaimWindowDays, isNull);
    });

    test('existing info-event fields still parse correctly when bond tags present', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_apply_to', 'take'],
        ['bond_slash_on_waiting_timeout', 'false'],
        ['bond_amount_pct', '0.02'],
        ['bond_base_amount_sats', '500'],
        ['bond_slash_node_share_pct', '0.25'],
        ['bond_payout_claim_window_days', '7'],
      ]);
      final instance = MostroInstance.fromEvent(event);

      expect(instance.mostroVersion, '0.13.0');
      expect(instance.maxOrderAmount, 1000000);
      expect(instance.fee, 0.006);
      expect(instance.expirationSeconds, 900);
    });
  });
}
