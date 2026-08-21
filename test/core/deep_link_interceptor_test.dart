import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/deep_link_interceptor.dart';

void main() {
  group('DeepLinkInterceptor.isCustomSchemeLocation', () {
    test('claims mostro links', () {
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation(
          'mostro:8927bb1d-da68-491e-b0e2-db0ed548d52c'
          '?relays=wss://relay.mostro.network',
        ),
        isTrue,
      );
      expect(DeepLinkInterceptor.isCustomSchemeLocation('mostro:'), isTrue);
    });

    test('claims other non-web schemes', () {
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation('lightning:lnbc1...'),
        isTrue,
      );
    });

    test('leaves app locations alone', () {
      expect(DeepLinkInterceptor.isCustomSchemeLocation('/'), isFalse);
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation('/take_sell/order-1'),
        isFalse,
      );
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation('/settings?tab=relays'),
        isFalse,
      );
      expect(DeepLinkInterceptor.isCustomSchemeLocation(''), isFalse);
    });

    test('leaves web locations alone', () {
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation('https://mostro.network/x'),
        isFalse,
      );
      expect(
        DeepLinkInterceptor.isCustomSchemeLocation('http://localhost:8080/'),
        isFalse,
      );
    });

    test('treats an unparseable location as an ordinary one', () {
      // Nothing we could hand to the deep link handler either.
      expect(DeepLinkInterceptor.isCustomSchemeLocation('::::'), isFalse);
    });
  });
}
