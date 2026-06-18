import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';

void main() {
  group('resolveTransport', () {
    test('protocol_version 2 → nip44', () {
      expect(resolveTransport(2), Transport.nip44);
    });

    test('protocol_version 1 → giftWrap', () {
      expect(resolveTransport(1), Transport.giftWrap);
    });

    test('null (tag absent / node info not yet fetched) → giftWrap', () {
      expect(resolveTransport(null), Transport.giftWrap);
    });

    test('unsupported version → degrades to giftWrap', () {
      expect(resolveTransport(3), Transport.giftWrap);
      expect(resolveTransport(0), Transport.giftWrap);
    });
  });
}
