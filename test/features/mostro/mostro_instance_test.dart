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

    test('bondSlashOnWaitingTimeout parses true and false case-insensitively', () {
      for (final entry in {
        'true': true,
        'TRUE': true,
        'false': false,
        'FALSE': false,
      }.entries) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_slash_on_waiting_timeout', entry.key],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondSlashOnWaitingTimeout, entry.value,
            reason: entry.key);
      }
    });

    test('bondSlashOnWaitingTimeout returns null for malformed values', () {
      for (final raw in ['foo', 'yes', 'no', '1', '0', '']) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_slash_on_waiting_timeout', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondSlashOnWaitingTimeout, isNull, reason: '"$raw"');
      }
    });

    test('empty tag value is treated as missing (preserves three-state semantics)', () {
      // bond_enabled with an empty value must not collapse to disabled —
      // it has to behave as if the tag were absent (unsupported).
      final event = buildEvent(const [
        ['bond_enabled', ''],
      ]);
      final instance = MostroInstance.fromEvent(event);
      expect(instance.bondPolicy, BondPolicy.unsupported);
    });

    test('whitespace-only tag value is treated as missing', () {
      final event = buildEvent(const [
        ['bond_enabled', '   '],
      ]);
      final instance = MostroInstance.fromEvent(event);
      expect(instance.bondPolicy, BondPolicy.unsupported);
    });

    test('bond_enabled with malformed value → unsupported (strict parse)', () {
      // Anything other than "true"/"false" must not masquerade as a
      // deliberate disabled policy. Corrupt payloads collapse to unsupported
      // so callers can fall back to legacy behaviour.
      for (final raw in ['yes', 'no', '1', '0', 'enabled', 'maybe']) {
        final event = buildEvent([
          ['bond_enabled', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondPolicy, BondPolicy.unsupported, reason: raw);
      }
    });

    test('empty tag entry in event does not throw on required getters', () {
      // Guards against a regression where `_getTagValue` indexed `t[0]`
      // without first checking the tag was non-empty, throwing RangeError
      // on malformed events that carry an empty tag list.
      final event = NostrEvent(
        id: 'a' * 64,
        kind: 38385,
        content: '',
        sig: 'b' * 128,
        pubkey: 'c' * 64,
        createdAt: DateTime(2025),
        tags: [
          const <String>[],
          ['d', 'c' * 64],
          ['mostro_version', '0.13.0'],
        ],
      );
      expect(() => event.mostroVersion, returnsNormally);
      expect(event.mostroVersion, '0.13.0');
    });

    test('bondSlashNodeSharePct out of [0.0, 1.0] range → null', () {
      for (final raw in ['-0.1', '1.5', '2', '-1']) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_slash_node_share_pct', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondSlashNodeSharePct, isNull, reason: raw);
      }
    });

    test('bondSlashNodeSharePct accepts boundary values 0.0 and 1.0', () {
      for (final raw in ['0.0', '1.0', '0.5']) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_slash_node_share_pct', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondSlashNodeSharePct, double.parse(raw), reason: raw);
      }
    });

    test('bondAmountPct out of [0.0, 1.0] range → null', () {
      for (final raw in ['-0.01', '1.5', '2']) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_amount_pct', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondAmountPct, isNull, reason: raw);
      }
    });

    test('bondBaseAmountSats negative value → null', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_base_amount_sats', '-100'],
      ]);
      final instance = MostroInstance.fromEvent(event);
      expect(instance.bondBaseAmountSats, isNull);
    });

    test('bondBaseAmountSats accepts zero', () {
      final event = buildEvent(const [
        ['bond_enabled', 'true'],
        ['bond_base_amount_sats', '0'],
      ]);
      final instance = MostroInstance.fromEvent(event);
      expect(instance.bondBaseAmountSats, 0);
    });

    test('bondPayoutClaimWindowDays zero or negative → null', () {
      for (final raw in ['0', '-1', '-15']) {
        final event = buildEvent([
          const ['bond_enabled', 'true'],
          ['bond_payout_claim_window_days', raw],
        ]);
        final instance = MostroInstance.fromEvent(event);
        expect(instance.bondPayoutClaimWindowDays, isNull, reason: raw);
      }
    });
  });

  group('MostroInstance protocol_version tag', () {
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

    test('tag absent → getter null, model defaults to v1', () {
      final event = buildEvent(const []);
      expect(event.protocolVersion, isNull);
      expect(MostroInstance.fromEvent(event).protocolVersion, 1);
    });

    test('protocol_version="2" → v2', () {
      final event = buildEvent(const [
        ['protocol_version', '2'],
      ]);
      expect(event.protocolVersion, 2);
      expect(MostroInstance.fromEvent(event).protocolVersion, 2);
    });

    test('protocol_version="1" → v1', () {
      final event = buildEvent(const [
        ['protocol_version', '1'],
      ]);
      expect(event.protocolVersion, 1);
      expect(MostroInstance.fromEvent(event).protocolVersion, 1);
    });

    test('unparseable value → getter null, model defaults to v1', () {
      final event = buildEvent(const [
        ['protocol_version', 'abc'],
      ]);
      expect(event.protocolVersion, isNull);
      expect(MostroInstance.fromEvent(event).protocolVersion, 1);
    });
  });
}
