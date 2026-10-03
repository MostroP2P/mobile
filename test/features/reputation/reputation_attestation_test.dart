import 'dart:convert';
import 'dart:io';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro;
import 'package:mostro_mobile/data/models/enums/cant_do_reason.dart';
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';

/// The protocol's test vectors (MostroP2P/protocol src/vectors/reputation_v1.json).
final Map<String, dynamic> vectors = jsonDecode(
  File('test/fixtures/reputation_v1.json').readAsStringSync(),
) as Map<String, dynamic>;

/// Well-formed attestations only the destination's context refuses.
const contextRefusals = [
  'identity_mismatch',
  'untrusted_issuer',
  'own_issuer_key'
];

/// Well-formed rebinds only the issuer's context refuses.
const rebindContextRefusals = ['signed_by_other_identity', 'other_issuer'];

void main() {
  final context = vectors['context'] as Map<String, dynamic>;
  final now = context['now'] as int;
  final maxLifetime = context['max_lifetime'] as int;
  final attestation = vectors['attestation'] as Map<String, dynamic>;

  group('reputation attestation vectors', () {
    test('the valid attestation parses to its expected fields', () {
      final valid = attestation['valid'] as Map<String, dynamic>;
      final expected = valid['expect'] as Map<String, dynamic>;
      final parsed = ReputationAttestation.parse(
        valid['json'] as String,
        now: now,
        maxLifetime: maxLifetime,
      );
      expect(parsed.id, valid['id']);
      expect(parsed.issuer, expected['issuer_key']);
      expect(parsed.destination, expected['destination']);
      expect(parsed.subject, expected['subject']);
      expect(parsed.reviews, expected['reviews']);
      expect(parsed.ratingText, expected['rating']);
      expect(parsed.since, expected['since']);
      expect(parsed.createdAt, expected['created_at']);
      expect(parsed.expiration, expected['expiration']);
      expect(parsed.json, valid['json'], reason: 'kept as received');
    });

    test('every accepted edge parses', () {
      for (final c in attestation['accepted'] as List) {
        expect(
          () => ReputationAttestation.parse(
            jsonEncode(c['event']),
            now: now,
            maxLifetime: maxLifetime,
          ),
          returnsNormally,
          reason: c['name'] as String,
        );
      }
    });

    test(
        'every invalid attestation is refused with its reason, or left to the context',
        () {
      final trusted = [
        for (final entry in context['trust_list'] as List)
          ...(entry['keys'] as List).cast<String>(),
      ];
      for (final c in attestation['invalid'] as List) {
        final name = c['name'] as String;
        final json = jsonEncode(c['event']);
        if (contextRefusals.contains(name)) {
          final parsed = ReputationAttestation.parse(
            json,
            now: now,
            maxLifetime: maxLifetime,
          );
          final refused = !trusted.contains(parsed.issuer) ||
              parsed.issuer == context['own_issuer_key'] ||
              parsed.destination != context['proven_identity'];
          expect(refused, isTrue, reason: name);
          continue;
        }
        expect(
          () => ReputationAttestation.parse(json,
              now: now, maxLifetime: maxLifetime),
          throwsA(
            isA<AttestationException>()
                .having((e) => e.reason, 'reason', c['reason']),
          ),
          reason: name,
        );
      }
    });

    test('ratings round half away from zero on the double', () {
      for (final c in vectors['rating_rounding'] as List) {
        final average = (c['average'] as num).toDouble();
        expect(formatRating(ratingHundredths(average)!), c['rating'],
            reason: '$average');
      }
      expect(ratingHundredths(double.nan), isNull);
    });
  });

  group('rebind authorisation vectors', () {
    final rebind = vectors['rebind'] as Map<String, dynamic>;
    final rebindContext = rebind['context'] as Map<String, dynamic>;
    final rebindNow = rebindContext['now'] as int;

    test('the valid rebind parses to its expected fields', () {
      final expected = rebind['valid']['expect'] as Map<String, dynamic>;
      final parsed = ReputationRebind.parse(rebind['valid']['json'] as String,
          now: rebindNow);
      expect(parsed.boundIdentity, expected['bound_identity']);
      expect(parsed.newIdentity, expected['new_identity']);
      expect(parsed.issuer, expected['issuer']);
      expect(parsed.createdAt, expected['created_at']);
      expect(parsed.expiration, expected['expiration']);
    });

    test('every invalid rebind is refused, by the event or by the issuer', () {
      for (final c in rebind['invalid'] as List) {
        final name = c['name'] as String;
        final json = jsonEncode(c['event']);
        if (rebindContextRefusals.contains(name)) {
          final parsed = ReputationRebind.parse(json, now: rebindNow);
          expect(
            parsed.boundIdentity != rebindContext['bound_identity'] ||
                parsed.issuer != rebindContext['issuer_key'],
            isTrue,
            reason: name,
          );
        } else {
          expect(
            () => ReputationRebind.parse(json, now: rebindNow),
            throwsA(isA<AttestationException>()),
            reason: name,
          );
        }
      }
    });

    test('an attestation is never taken for a rebind, nor the reverse', () {
      expect(
        () => ReputationRebind.parse(
          attestation['valid']['json'] as String,
          now: now,
        ),
        throwsA(isA<AttestationException>()),
      );
      expect(
        () => ReputationAttestation.parse(
          rebind['valid']['json'] as String,
          now: rebindNow,
        ),
        throwsA(isA<AttestationException>()),
      );
    });

    test('a built rebind parses back to what was built', () {
      final secrets = vectors['secret_keys'] as Map<String, dynamic>;
      final bound = NostrKeyPairs(private: secrets['identity'] as String);
      final issuer =
          NostrKeyPairs(private: secrets['issuer-a'] as String).public;
      final newIdentity =
          NostrKeyPairs(private: secrets['new-identity'] as String).public;
      final json = ReputationRebind.build(
        boundIdentity: bound,
        issuer: issuer,
        newIdentity: newIdentity,
        createdAt: rebindNow,
      );
      final parsed = ReputationRebind.parse(json, now: rebindNow);
      expect(parsed.boundIdentity, bound.public);
      expect(parsed.issuer, issuer);
      expect(parsed.newIdentity, newIdentity);
      expect(parsed.expiration - parsed.createdAt, rebindMaxLifetimeSecs);
    });
  });

  group('reputation messages', () {
    test('an export request has the documented wire shape and parses back', () {
      final message = MostroMessage(
        action: mostro.Action.exportReputation,
        requestId: 4126,
        payload: const ReputationExportRequest(destination: 'ab'),
      );
      final json = message.toJson();
      expect(json['action'], 'export-reputation');
      expect(json['payload'], {
        'reputation_export_request': {'destination': 'ab', 'rebind': null},
      });
      expect(json.containsKey('id'), isFalse);
      final back = MostroMessage.fromJson({'order': json});
      expect(back.action, mostro.Action.exportReputation);
      final payload = back.payload as ReputationExportRequest;
      expect(payload.destination, 'ab');
      expect(payload.rebind, isNull);
    });

    test('the attestation payload travels as the event JSON string', () {
      final reply = MostroMessage.fromJson({
        'order': {
          'version': 2,
          'request_id': 4126,
          'action': 'reputation-exported',
          'payload': {'reputation_attestation': attestation['valid']['json']},
        },
      });
      expect(reply.action, mostro.Action.reputationExported);
      final payload = reply.payload as ReputationAttestationPayload;
      expect(
        ReputationAttestation.parse(payload.attestation, now: now).id,
        attestation['valid']['id'],
      );
      final import = MostroMessage(
        action: mostro.Action.importReputation,
        payload: ReputationAttestationPayload(payload.attestation),
      );
      expect(import.toJson()['payload'], {
        'reputation_attestation': attestation['valid']['json'],
      });
    });

    test(
        'the new cant-do reasons parse, and an unknown one degrades to unknown',
        () {
      for (final reason in [
        'reputation_identity_required',
        'not_eligible_for_reputation_export',
        'reputation_bound_to_other_identity',
        'invalid_reputation_rebind',
        'invalid_reputation_attestation',
        'untrusted_reputation_issuer',
        'expired_reputation_attestation',
        'reputation_identity_mismatch',
        'reputation_already_imported',
      ]) {
        expect(CantDoReason.fromString(reason).value, reason);
      }
      expect(CantDoReason.fromString('a_reason_from_the_future'),
          CantDoReason.unknown);
    });
  });
}
