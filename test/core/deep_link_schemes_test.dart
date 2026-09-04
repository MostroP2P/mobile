import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/deep_link_schemes.dart';

void main() {
  group('isCustomSchemeLocation', () {
    test('claims mostro links', () {
      expect(
        isCustomSchemeLocation(
          'mostro:8927bb1d-da68-491e-b0e2-db0ed548d52c'
          '?relays=wss://relay.mostro.network',
        ),
        isTrue,
      );
      expect(isCustomSchemeLocation('mostro:'), isTrue);
    });

    test('claims other non-web schemes', () {
      expect(
        isCustomSchemeLocation('lightning:lnbc1...'),
        isTrue,
      );
    });

    test('leaves app locations alone', () {
      expect(isCustomSchemeLocation('/'), isFalse);
      expect(
        isCustomSchemeLocation('/take_sell/order-1'),
        isFalse,
      );
      expect(
        isCustomSchemeLocation('/settings?tab=relays'),
        isFalse,
      );
      expect(isCustomSchemeLocation(''), isFalse);
    });

    test('claims schemes that merely start like a web one', () {
      expect(
        isCustomSchemeLocation('httpfoo://example.com'),
        isTrue,
      );
    });

    test('leaves web locations alone', () {
      expect(
        isCustomSchemeLocation('https://mostro.network/x'),
        isFalse,
      );
      expect(
        isCustomSchemeLocation('http://localhost:8080/'),
        isFalse,
      );
      // Uri normalises the scheme, so no case handling of our own is needed.
      expect(
        isCustomSchemeLocation('HTTPS://mostro.network/x'),
        isFalse,
      );
    });

    test('treats an unparseable location as an ordinary one', () {
      // Nothing we could hand to the deep link handler either.
      expect(isCustomSchemeLocation('::::'), isFalse);
    });
  });
}
