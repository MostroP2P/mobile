import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// The decrypt/wrap hot paths guard their session-derived private keys with a
/// syntactic check. The previous guard (`isValidPrivateKey`) constructed a
/// full EC key pair — one scalar multiplication (5-30 ms of BigInt math on a
/// mid-range phone) per incoming gift wrap, spent validating a hex string the
/// app derived itself. `isValidPrivateKey` stays for real user input
/// (auth/key import), where deep validation is worth its cost.
void main() {
  // Order of the secp256k1 group.
  const curveOrder =
      'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364141';

  group('NostrUtils.isCanonicalPrivateKey', () {
    test('accepts a 64-character hex key in either case', () {
      expect(NostrUtils.isCanonicalPrivateKey('a' * 64), isTrue);
      expect(NostrUtils.isCanonicalPrivateKey('0123456789abcdef' * 4), isTrue);
      expect(NostrUtils.isCanonicalPrivateKey('ABCDEF0123456789' * 4), isTrue);
    });

    test('rejects wrong lengths and non-hex input', () {
      expect(NostrUtils.isCanonicalPrivateKey(''), isFalse);
      expect(NostrUtils.isCanonicalPrivateKey('a' * 63), isFalse);
      expect(NostrUtils.isCanonicalPrivateKey('a' * 65), isFalse);
      expect(NostrUtils.isCanonicalPrivateKey('g' * 64), isFalse);
      expect(NostrUtils.isCanonicalPrivateKey('nsec1${'a' * 59}'), isFalse);
    });

    test('rejects scalars outside the secp256k1 range', () {
      // Zero has no public key: `G * 0` is the point at infinity, and
      // bip340's unchecked `getPublicKey` fails on it with a _TypeError
      // rather than the ArgumentError the entry points promise.
      expect(NostrUtils.isCanonicalPrivateKey('0' * 64), isFalse);
      expect(NostrUtils.isCanonicalPrivateKey(curveOrder), isFalse);
      expect(
        NostrUtils.isCanonicalPrivateKey(
          'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364142',
        ),
        isFalse,
      );
      expect(NostrUtils.isCanonicalPrivateKey('f' * 64), isFalse);
    });

    test('accepts the smallest and largest valid scalars', () {
      expect(NostrUtils.isCanonicalPrivateKey('${'0' * 63}1'), isTrue);
      expect(
        NostrUtils.isCanonicalPrivateKey(
          'fffffffffffffffffffffffffffffffebaaedce6af48a03bbfd25e8cd0364140',
        ),
        isTrue,
      );
    });
  });

  group('entry-point guards honour their ArgumentError contract', () {
    test('createNIP59Event rejects an out-of-range sender key', () {
      // Without the range check this reaches bip340 and throws a _TypeError.
      expect(
        () => NostrUtils.createNIP59Event('hi', 'a' * 64, '0' * 64),
        throwsArgumentError,
      );
      expect(
        () => NostrUtils.createNIP59Event('hi', 'a' * 64, 'f' * 64),
        throwsArgumentError,
      );
    });
  });
}
