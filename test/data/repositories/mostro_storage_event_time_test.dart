import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:sembast/sembast_memory.dart';

/// The history used to be ordered by the local receive time stamped at write.
/// Relays replay pending events newest-first and the decrypt pipeline is
/// concurrent, so an earlier message could be written after a later one and
/// become the "latest" message the order state is derived from.
void main() {
  late MostroStorage storage;

  setUp(() async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('event_time_test.db');
    storage = MostroStorage(db: db);
  });

  MostroMessage message(Action action, {int? eventCreatedAt}) => MostroMessage(
        action: action,
        id: 'order-a',
        eventCreatedAt: eventCreatedAt,
      );

  test('the latest message follows the event time, not the write order',
      () async {
    // Arrange: the newer event is decrypted and written first.
    await storage.addMessage(
      'newer',
      message(Action.holdInvoicePaymentAccepted, eventCreatedAt: 2000),
    );
    await storage.addMessage(
      'older',
      message(Action.waitingSellerToPay, eventCreatedAt: 1000),
    );

    // Act
    final history = await storage.getAllMessagesForOrderId('order-a');
    final latest = await storage.getLatestMessageById('order-a');

    // Assert
    expect(history.map((m) => m.action),
        [Action.holdInvoicePaymentAccepted, Action.waitingSellerToPay]);
    expect(latest?.action, Action.holdInvoicePaymentAccepted);
  });

  test('legacy rows without an event time keep their receive-time order',
      () async {
    final first = message(Action.newOrder)..timestamp = 1000;
    final second = message(Action.payInvoice)..timestamp = 2000;
    await storage.addMessage('k1', first);
    await storage.addMessage('k2', second);

    final history = await storage.getAllMessagesForOrderId('order-a');

    expect(history.map((m) => m.action), [Action.payInvoice, Action.newOrder]);
  });

  _typedLookup();

  test('the event time survives a round trip through the database', () async {
    await storage.addMessage(
      'k1',
      message(Action.waitingSellerToPay, eventCreatedAt: 1234),
    );
    final reopened = MostroStorage(db: storage.db);

    final history = await reopened.getAllMessagesForOrderId('order-a');

    expect(history.single.eventCreatedAt, 1234);
  });
}

void _typedLookup() {
  test('the typed latest lookup follows the event time too', () async {
    final db =
        await newDatabaseFactoryMemory().openDatabase('typed_lookup_test.db');
    final storage = MostroStorage(db: db);
    Order order(Status status) => Order(
          id: 'order-a',
          kind: OrderType.sell,
          status: status,
          fiatCode: 'VES',
          fiatAmount: 100,
          paymentMethod: 'face to face',
        );

    await storage.addMessage(
      'newer',
      MostroMessage<Order>(
        action: Action.holdInvoicePaymentAccepted,
        id: 'order-a',
        eventCreatedAt: 2000,
        payload: order(Status.active),
      ),
    );
    await storage.addMessage(
      'older',
      MostroMessage<Order>(
        action: Action.waitingSellerToPay,
        id: 'order-a',
        eventCreatedAt: 1000,
        payload: order(Status.waitingPayment),
      ),
    );

    final latest = await storage.getLatestMessageOfTypeById<Order>('order-a');

    expect(latest?.getPayload<Order>()?.status, Status.active);
  });
}
