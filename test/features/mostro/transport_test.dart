import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';

void main() {
  group('resolveTransport', () {
    test('protocol_version 1 → giftWrap', () {
      expect(resolveTransport(1), Transport.giftWrap);
    });

    test('protocol_version 2 → nip44', () {
      expect(resolveTransport(2), Transport.nip44);
    });

    // "Unknown" is a state any relay can create for free by not serving the
    // node's info event. Resolving it to v1 — whose intake authenticates
    // nothing — made omission a downgrade primitive, so it resolves to the
    // safe default instead.
    test('null (tag absent, info not fetched, or withheld) → default', () {
      expect(resolveTransport(null), kDefaultTransport);
      expect(kDefaultTransport, Transport.nip44);
    });

    // Same reasoning: degrading an unrecognised version to v1 would let any
    // party who can put a number in that tag pick the forgeable transport.
    test('unsupported version degrades upwards to the default, not to v1', () {
      expect(resolveTransport(3), kDefaultTransport);
      expect(resolveTransport(99), kDefaultTransport);
      expect(resolveTransport(0), kDefaultTransport);
      expect(resolveTransport(-1), kDefaultTransport);
    });
  });

  // Callers that need to know whether a version is one this build understands
  // ask here rather than hardcoding the set, so the two cannot drift apart as
  // versions are added.
  group('tryResolveTransport', () {
    test('names the transport for a version this client speaks', () {
      expect(tryResolveTransport(1), Transport.giftWrap);
      expect(tryResolveTransport(2), Transport.nip44);
    });

    test('has no answer for a version this client does not speak', () {
      expect(tryResolveTransport(3), isNull);
      expect(tryResolveTransport(99), isNull);
      expect(tryResolveTransport(0), isNull);
      expect(tryResolveTransport(-1), isNull);
    });

    test('has no answer when there is no version at all', () {
      expect(tryResolveTransport(null), isNull);
    });

    // The distinction resolveTransport erases: it answers kDefaultTransport for
    // both, and only logs for the second.
    test('separates "nothing advertised" from "unsupported"', () {
      expect(resolveTransport(null), resolveTransport(3));
      expect(tryResolveTransport(null), tryResolveTransport(3));
    });
  });

  group('anchoredProtocolVersion', () {
    test('knows nothing when neither source knows anything', () {
      expect(anchoredProtocolVersion(null, null), isNull);
    });

    test('uses the advertised version when nothing is remembered', () {
      expect(anchoredProtocolVersion(_v(1, _beforeMigration), null), 1);
      expect(anchoredProtocolVersion(_v(2, _migration), null), 2);
    });

    test('uses the remembered version when nothing is advertised', () {
      expect(anchoredProtocolVersion(null, _v(1, _beforeMigration)), 1);
      expect(anchoredProtocolVersion(null, _v(2, _migration)), 2);
    });

    test('lets a node upgrade', () {
      expect(
        anchoredProtocolVersion(_v(2, _migration), _v(1, _beforeMigration)),
        2,
      );
    });

    // The attack the anchor exists to stop: a relay withholds the node's
    // current event and serves a pre-migration one it cannot re-date.
    test('refuses an assertion older than the one already verified', () {
      expect(
        anchoredProtocolVersion(_v(1, _beforeMigration), _v(2, _migration)),
        2,
      );
    });

    // The other half of the same rule, and the reason it is dated rather than
    // monotonic: an operator rolling a bad v2 rollout back publishes a genuine,
    // newer, signed v1 assertion. Refusing it would partition the client from
    // the node permanently and silently.
    test('follows a node that asserts v1 again more recently', () {
      expect(
        anchoredProtocolVersion(_v(1, _rollback), _v(2, _migration)),
        1,
      );
    });

    test('agreeing sources pass straight through', () {
      expect(anchoredProtocolVersion(_v(2, _migration), _v(2, _migration)), 2);
      expect(
        anchoredProtocolVersion(
          _v(1, _beforeMigration),
          _v(1, _beforeMigration),
        ),
        1,
      );
    });

    // Freshness cannot separate same-second assertions — NIP-01's id tie-break
    // runs upstream, on events, not here — so the safer transport wins.
    test('a same-second downgrade loses to the higher version', () {
      expect(
        anchoredProtocolVersion(_v(1, _migration), _v(2, _migration)),
        2,
      );
    });

    group('an assertion that cannot be dated', () {
      test('never lowers a dated one', () {
        expect(
          anchoredProtocolVersion(
            const VersionAssertion(1, null),
            _v(2, _migration),
          ),
          2,
        );
      });

      test('is not lowered by a dated one either', () {
        expect(
          anchoredProtocolVersion(
            _v(1, _rollback),
            const VersionAssertion(2, null),
          ),
          2,
        );
      });

      test('falls back to the higher version when both are undated', () {
        expect(
          anchoredProtocolVersion(
            const VersionAssertion(1, null),
            const VersionAssertion(2, null),
          ),
          2,
        );
      });
    });
  });

  group('resolveAnchoredTransport', () {
    test('first contact with a legacy v1 node still reaches v1', () {
      expect(
        resolveAnchoredTransport(_v(1, _beforeMigration), null),
        Transport.giftWrap,
      );
    });

    test('first contact with a v2 node reaches v2', () {
      expect(
        resolveAnchoredTransport(_v(2, _migration), null),
        Transport.nip44,
      );
    });

    // The attack this whole chain exists to stop: the node is known to speak
    // v2, and a relay tries to put the client back on the forgeable transport.
    test('a replayed v1 advertisement cannot downgrade a known v2 node', () {
      expect(
        resolveAnchoredTransport(_v(1, _beforeMigration), _v(2, _migration)),
        Transport.nip44,
      );
    });

    test('withholding the info event cannot downgrade a known v2 node', () {
      expect(
        resolveAnchoredTransport(null, _v(2, _migration)),
        Transport.nip44,
      );
    });

    test('withholding the info event on first contact reaches the default',
        () {
      expect(resolveAnchoredTransport(null, null), kDefaultTransport);
    });

    test('a node that has only ever been seen at v1 stays reachable', () {
      expect(
        resolveAnchoredTransport(
          _v(1, _beforeMigration),
          _v(1, _beforeMigration),
        ),
        Transport.giftWrap,
      );
    });

    test('a v1 node that upgrades is followed to v2', () {
      expect(
        resolveAnchoredTransport(_v(2, _migration), _v(1, _beforeMigration)),
        Transport.nip44,
      );
    });

    test('a v2 node that the operator rolls back is followed to v1', () {
      expect(
        resolveAnchoredTransport(_v(1, _rollback), _v(2, _migration)),
        Transport.giftWrap,
      );
    });
  });
}

/// Three moments in a node's life, as `created_at` seconds: the last info
/// event before the operator migrated, the one that announced v2, and the one
/// that announced a rollback to v1.
const int _beforeMigration = 1000;
const int _migration = 2000;
const int _rollback = 3000;

VersionAssertion _v(int version, int seconds) => VersionAssertion(
      version,
      DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true),
    );
