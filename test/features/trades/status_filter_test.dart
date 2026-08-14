import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/features/trades/providers/trades_provider.dart';

void main() {
  group('matchesStatusFilter', () {
    test('canceled filter also matches admin-canceled orders', () {
      expect(matchesStatusFilter(Status.canceledByAdmin, Status.canceled),
          isTrue,
          reason: 'the picker has no separate admin-canceled entry, so these '
              'orders must not drop out of every filter');
    });

    test('canceled filter matches plain canceled orders', () {
      expect(matchesStatusFilter(Status.canceled, Status.canceled), isTrue);
    });

    test('canceled filter does not match unrelated statuses', () {
      expect(matchesStatusFilter(Status.active, Status.canceled), isFalse);
      expect(matchesStatusFilter(Status.settledByAdmin, Status.canceled),
          isFalse);
      expect(
          matchesStatusFilter(Status.cooperativelyCanceled, Status.canceled),
          isFalse,
          reason: 'cooperative cancellation is its own filterable status');
    });

    test('other filters match exactly', () {
      for (final status in Status.values) {
        expect(matchesStatusFilter(status, Status.active),
            equals(status == Status.active));
      }
    });
  });
}
