import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/chat_cursor_store.dart';
import 'package:mostro_mobile/services/nwc/nwc_client.dart';

/// Pins the `since` bound on the NWC kind-23195 response subscription.
///
/// Without a `since` the relay replays the wallet's whole response history on
/// every request; with too tight a `since` a clock-skewed wallet has its live
/// response dropped by the relay and every NWC operation times out.
void main() {
  const walletPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('NwcClient.responseFilter', () {
    test('subscribes to kind 23195 from the wallet author only', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);

      // Act
      final filter = NwcClient.responseFilter(walletPubkey, now: now);

      // Assert
      expect(filter.kinds, [23195]);
      expect(filter.authors, [walletPubkey]);
    });

    test('bounds the replay with a since cutoff', () {
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);

      // Act
      final filter = NwcClient.responseFilter(walletPubkey, now: now);

      // Assert
      expect(filter.since, isNotNull);
      expect(filter.since, now.subtract(NwcClient.responseReplayWindow));
    });

    test('leaves at least ten minutes of wallet clock skew', () {
      // A response signed by a wallet whose clock lags the phone must still
      // pass the relay-side since filter.
      // Arrange
      final now = DateTime.utc(2026, 1, 1, 12);
      final laggingWalletResponse = now.subtract(const Duration(minutes: 9));

      // Act
      final filter = NwcClient.responseFilter(walletPubkey, now: now);

      // Assert
      expect(NwcClient.responseReplayWindow,
          greaterThanOrEqualTo(const Duration(minutes: 10)));
      expect(filter.since!.isBefore(laggingWalletResponse), isTrue);
    });

    test('matches the skew budget already used for relay since filters', () {
      // Assert
      expect(NwcClient.responseReplayWindow, ChatCursorStore.cursorOverlap);
    });
  });
}
