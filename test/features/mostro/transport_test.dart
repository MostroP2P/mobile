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

    test('null (tag absent / node info not yet fetched) → nip44', () {
      // Gift wrap is obsolete; defaulting to v2 avoids a useless kind-1059
      // REQ + resubscribe at every cold start while the node info loads.
      expect(resolveTransport(null), Transport.nip44);
    });

    test('unknown versions assume the live transport (nip44)', () {
      expect(resolveTransport(3), Transport.nip44);
      expect(resolveTransport(0), Transport.nip44);
    });
  });
}
