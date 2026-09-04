import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
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
