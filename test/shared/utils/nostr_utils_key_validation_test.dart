import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// The decrypt/wrap hot paths guard their session-derived private keys with a
/// syntactic check. The previous guard (`isValidPrivateKey`) constructed a
/// full EC key pair — one scalar multiplication (5-30 ms of BigInt math on a
/// mid-range phone) per incoming gift wrap, spent validating a hex string the
/// app derived itself. `isValidPrivateKey` stays for real user input
/// (auth/key import), where deep validation is worth its cost.
void main() {
  group('NostrUtils.isHexPrivateKey', () {
    test('accepts a 64-character hex key in either case', () {
      expect(NostrUtils.isHexPrivateKey('a' * 64), isTrue);
      expect(NostrUtils.isHexPrivateKey('0123456789abcdef' * 4), isTrue);
      expect(NostrUtils.isHexPrivateKey('ABCDEF0123456789' * 4), isTrue);
    });

    test('rejects wrong lengths and non-hex input', () {
      expect(NostrUtils.isHexPrivateKey(''), isFalse);
      expect(NostrUtils.isHexPrivateKey('a' * 63), isFalse);
      expect(NostrUtils.isHexPrivateKey('a' * 65), isFalse);
      expect(NostrUtils.isHexPrivateKey('g' * 64), isFalse);
      expect(NostrUtils.isHexPrivateKey('nsec1${'a' * 59}'), isFalse);
    });
  });
}
