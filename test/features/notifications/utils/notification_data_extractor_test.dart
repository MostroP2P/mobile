import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/features/notifications/utils/notification_data_extractor.dart';

MostroMessage<Peer> reputationNotice(Action action) => MostroMessage<Peer>(
      action: action,
      id: 'order-1',
      payload: Peer(
        publicKey: '',
        reputation:
            const UserInfo(rating: 4.375, reviews: 4, operatingDays: 64),
      ),
    );

void main() {
  group('NotificationDataExtractor', () {
    test('the taker-reputation notice produces no notification', () async {
      // Filtered inside the extractor so the background service, which calls
      // it directly, cannot fire a second notification for the same action
      for (final action in [Action.payInvoice, Action.addInvoice]) {
        expect(
          await NotificationDataExtractor.extractFromMostroMessage(
              reputationNotice(action), null),
          isNull,
          reason: '$action notice must stay silent',
        );
      }
    });

    test('the real flow message still notifies', () async {
      final data = await NotificationDataExtractor.extractFromMostroMessage(
        MostroMessage(action: Action.addInvoice, id: 'order-1'),
        null,
      );

      expect(data, isNotNull);
      expect(data!.action, Action.addInvoice);
      expect(data.orderId, 'order-1');
    });
  });
}
