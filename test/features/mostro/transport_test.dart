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

  group('anchoredProtocolVersion', () {
    test('knows nothing when neither source knows anything', () {
      expect(anchoredProtocolVersion(null, null), isNull);
    });

    test('uses the advertised version when nothing is remembered', () {
      expect(anchoredProtocolVersion(1, null), 1);
      expect(anchoredProtocolVersion(2, null), 2);
    });

    test('uses the remembered version when nothing is advertised', () {
      expect(anchoredProtocolVersion(null, 1), 1);
      expect(anchoredProtocolVersion(null, 2), 2);
    });

    test('lets a node upgrade', () {
      expect(anchoredProtocolVersion(2, 1), 2);
    });

    test('refuses to walk a node back below what it has proven', () {
      expect(anchoredProtocolVersion(1, 2), 2);
    });

    test('agreeing sources pass straight through', () {
      expect(anchoredProtocolVersion(2, 2), 2);
      expect(anchoredProtocolVersion(1, 1), 1);
    });
  });

  group('resolveAnchoredTransport', () {
    test('first contact with a legacy v1 node still reaches v1', () {
      expect(resolveAnchoredTransport(1, null), Transport.giftWrap);
    });

    test('first contact with a v2 node reaches v2', () {
      expect(resolveAnchoredTransport(2, null), Transport.nip44);
    });

    // The attack this whole chain exists to stop: the node is known to speak
    // v2, and a relay tries to put the client back on the forgeable transport.
    test('a replayed v1 advertisement cannot downgrade a known v2 node', () {
      expect(resolveAnchoredTransport(1, 2), Transport.nip44);
    });

    test('withholding the info event cannot downgrade a known v2 node', () {
      expect(resolveAnchoredTransport(null, 2), Transport.nip44);
    });

    test('withholding the info event on first contact reaches the default',
        () {
      expect(resolveAnchoredTransport(null, null), kDefaultTransport);
    });

    test('a node that has only ever been seen at v1 stays reachable', () {
      expect(resolveAnchoredTransport(1, 1), Transport.giftWrap);
    });

    test('a v1 node that upgrades is followed to v2', () {
      expect(resolveAnchoredTransport(2, 1), Transport.nip44);
    });
  });
}
