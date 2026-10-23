import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';

/// Kind of a reputation attestation and of a rebind authorisation.
/// Never published to relays: it travels inside encrypted messages.
/// https://mostro.network/protocol/reputation_attestation.html
const int reputationAttestationKind = 38388;

/// Lifetime an issuer gives an attestation, and the cap a destination
/// enforces by default: 7 days.
const int attestationLifetimeSecs = 7 * 24 * 60 * 60;

/// Clock skew tolerated on `created_at` and `expiration`.
const int maxClockSkewSecs = 300;

/// Longest a rebind authorisation may live.
const int rebindMaxLifetimeSecs = 3600;

const _attestationDocument = 'reputation-attestation';
const _rebindDocument = 'reputation-rebind';
const _minReviews = 5;
const _maxReviews = 4294967295;
const _minSince = 1577836800; // 2020-01-01
const _secondsPerDay = 86400;
final _hexKey = RegExp(r'^[0-9a-f]{64}$');
final _subject = RegExp(r'^[0-9A-Za-z_-]{1,64}$');
final _decimal = RegExp(r'^(0|[1-9][0-9]*)$');
final _rating = RegExp(r'^[0-9]\.[0-9]{2}$');

/// Why an attestation or rebind authorisation was refused, as the snake_case
/// `cant-do` reason a destination answers with.
class AttestationException implements Exception {
  final String reason;
  final String detail;

  const AttestationException(this.reason, this.detail);

  bool get expired => reason == 'expired_reputation_attestation';

  @override
  String toString() => 'AttestationException($reason: $detail)';
}

/// A verified reputation attestation: the reputation an issuer attests for
/// one destination identity.
class ReputationAttestation {
  final String id;
  final String issuer;
  final String destination;
  final String subject;
  final int reviews;
  final int ratingHundredths;
  final int since;
  final int createdAt;
  final int expiration;

  /// The event exactly as received, to forward unchanged on import.
  final String json;

  const ReputationAttestation({
    required this.id,
    required this.issuer,
    required this.destination,
    required this.subject,
    required this.reviews,
    required this.ratingHundredths,
    required this.since,
    required this.createdAt,
    required this.expiration,
    required this.json,
  });

  /// Average rating as written in the event, e.g. `4.87`.
  String get ratingText => formatRating(ratingHundredths);

  double get rating => ratingHundredths / 100;

  /// Parse and verify an attestation the way a destination does, apart from
  /// the checks that depend on it: the trust list, its own issuer key and
  /// the identity the transport proves stay with the caller.
  static ReputationAttestation parse(
    String json, {
    required int now,
    int maxLifetime = attestationLifetimeSecs,
  }) {
    const invalid = 'invalid_reputation_attestation';
    final event = _verifiedEvent(json, _attestationDocument, invalid);
    final tags = _singleTags(
      event,
      ['p', 'subject', 'reviews', 'rating', 'since', 'expiration'],
      invalid,
    );
    final destination = tags['p']!;
    if (!_hexKey.hasMatch(destination)) {
      throw const AttestationException(invalid, 'p is not lowercase hex');
    }
    if (!_subject.hasMatch(tags['subject']!)) {
      throw const AttestationException(invalid, 'invalid subject');
    }
    final reviews = _parseDecimal(tags['reviews']!);
    if (reviews == null || reviews < _minReviews || reviews > _maxReviews) {
      throw const AttestationException(invalid, 'invalid reviews');
    }
    final hundredths = _parseRating(tags['rating']!);
    if (hundredths == null) {
      throw const AttestationException(invalid, 'invalid rating');
    }
    final createdAt = event['created_at'] as int;
    final since = _parseDecimal(tags['since']!);
    if (since == null ||
        since % _secondsPerDay != 0 ||
        since < _minSince ||
        since > createdAt) {
      throw const AttestationException(invalid, 'invalid since');
    }
    final expiration = _parseDecimal(tags['expiration']!);
    if (expiration == null || expiration <= createdAt) {
      throw const AttestationException(invalid, 'invalid expiration');
    }
    _checkClock(createdAt, expiration, now, maxLifetime, invalid);
    return ReputationAttestation(
      id: event['id'] as String,
      issuer: event['pubkey'] as String,
      destination: destination,
      subject: tags['subject']!,
      reviews: reviews,
      ratingHundredths: hundredths,
      since: since,
      createdAt: createdAt,
      expiration: expiration,
      json: json,
    );
  }
}

/// A verified rebind authorisation: the identity a source account is bound to
/// consents to moving the binding to a new identity.
class ReputationRebind {
  final String id;
  final String boundIdentity;
  final String newIdentity;
  final String issuer;
  final int createdAt;
  final int expiration;

  const ReputationRebind({
    required this.id,
    required this.boundIdentity,
    required this.newIdentity,
    required this.issuer,
    required this.createdAt,
    required this.expiration,
  });

  /// Sign a rebind authorisation with the currently bound identity, as JSON.
  static String build({
    required NostrKeyPairs boundIdentity,
    required String issuer,
    required String newIdentity,
    required int createdAt,
    int lifetime = rebindMaxLifetimeSecs,
  }) {
    if (lifetime <= 0 || lifetime > rebindMaxLifetimeSecs) {
      throw ArgumentError.value(lifetime, 'lifetime');
    }
    final event = NostrEvent.fromPartialData(
      kind: reputationAttestationKind,
      content: '',
      keyPairs: boundIdentity,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
      tags: [
        ['p', newIdentity],
        ['issuer', issuer],
        ['expiration', '${createdAt + lifetime}'],
        ['z', _rebindDocument],
      ],
    );
    return jsonEncode({
      'id': event.id,
      'pubkey': event.pubkey,
      'created_at': createdAt,
      'kind': event.kind,
      'tags': event.tags,
      'content': event.content,
      'sig': event.sig,
    });
  }

  /// Parse and verify a rebind authorisation. Whether it is signed by the
  /// identity actually bound, and names the right issuer, is the caller's.
  static ReputationRebind parse(String json, {required int now}) {
    const invalid = 'invalid_reputation_rebind';
    final event = _verifiedEvent(json, _rebindDocument, invalid);
    final tags = _singleTags(event, ['p', 'issuer', 'expiration'], invalid);
    if (!_hexKey.hasMatch(tags['p']!) || !_hexKey.hasMatch(tags['issuer']!)) {
      throw const AttestationException(invalid, 'invalid key');
    }
    final createdAt = event['created_at'] as int;
    final expiration = _parseDecimal(tags['expiration']!);
    if (expiration == null || expiration <= createdAt) {
      throw const AttestationException(invalid, 'invalid expiration');
    }
    _checkClock(createdAt, expiration, now, rebindMaxLifetimeSecs, invalid);
    return ReputationRebind(
      id: event['id'] as String,
      boundIdentity: event['pubkey'] as String,
      newIdentity: tags['p']!,
      issuer: tags['issuer']!,
      createdAt: createdAt,
      expiration: expiration,
    );
  }
}

/// The `rating` an issuer writes for an internal average, in hundredths:
/// `clamp(round(average × 100), 100, 500)`, rounding half away from zero on
/// the double. `null` for a non-finite average.
int? ratingHundredths(double average) {
  if (!average.isFinite) return null;
  return (average * 100).round().clamp(100, 500);
}

String formatRating(int hundredths) =>
    '${hundredths ~/ 100}.${(hundredths % 100).toString().padLeft(2, '0')}';

/// Id, signature, kind and `z`, in that order.
Map<String, dynamic> _verifiedEvent(
  String json,
  String document,
  String reason,
) {
  final Map<String, dynamic> event;
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map<String, dynamic>) throw const FormatException();
    event = decoded;
    final tags = (event['tags'] as List)
        .map((tag) => (tag as List).map((v) => v as String).toList())
        .toList();
    event['tags'] = tags;
    final id = NostrEvent.getEventId(
      kind: event['kind'] as int,
      content: event['content'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int) * 1000,
      ),
      tags: tags,
      pubkey: event['pubkey'] as String,
    );
    if (id != event['id'] ||
        !NostrKeyPairs.verify(
          event['pubkey'] as String,
          id,
          event['sig'] as String,
        )) {
      throw AttestationException(reason, 'invalid id or signature');
    }
  } on AttestationException {
    rethrow;
  } catch (_) {
    throw AttestationException(reason, 'not a valid Nostr event');
  }
  if (event['kind'] != reputationAttestationKind) {
    throw AttestationException(reason, 'wrong kind');
  }
  final documents = _values(event, 'z');
  if (documents.length != 1 || documents.single != document) {
    throw AttestationException(reason, 'wrong z tag');
  }
  return event;
}

List<String> _values(Map<String, dynamic> event, String name) => [
      for (final tag in event['tags'] as List<List<String>>)
        if (tag.isNotEmpty && tag[0] == name) tag.length > 1 ? tag[1] : '',
    ];

Map<String, String> _singleTags(
  Map<String, dynamic> event,
  List<String> names,
  String reason,
) {
  return {
    for (final name in names)
      name: () {
        final values = _values(event, name);
        if (values.length != 1) {
          throw AttestationException(reason, 'tag $name must appear once');
        }
        return values.single;
      }(),
  };
}

int? _parseDecimal(String value) =>
    _decimal.hasMatch(value) ? int.tryParse(value) : null;

int? _parseRating(String value) {
  if (!_rating.hasMatch(value)) return null;
  final hundredths = int.parse(value.replaceAll('.', ''));
  return hundredths >= 100 && hundredths <= 500 ? hundredths : null;
}

void _checkClock(
  int createdAt,
  int expiration,
  int now,
  int maxLifetime,
  String reason,
) {
  if (createdAt > now + maxClockSkewSecs) {
    throw AttestationException(reason, 'created in the future');
  }
  if (now > expiration + maxClockSkewSecs) {
    throw AttestationException(
      reason == 'invalid_reputation_attestation'
          ? 'expired_reputation_attestation'
          : reason,
      'expired',
    );
  }
  if (expiration - createdAt > maxLifetime) {
    throw AttestationException(reason, 'lifetime too long');
  }
}
