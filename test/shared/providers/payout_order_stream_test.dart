import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/enums.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:sembast/sembast_memory.dart';

/// End-to-end over the real storage: the selector assumes the history arrives
/// newest first, and nothing else pins that. If the order ever flipped, the
/// screen would quietly pick the oldest payout message instead (#748).
void main() {
  const orderId = 'order-1';

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    db = await newDatabaseFactoryMemory().openDatabase('payout_stream.db');
    container = ProviderContainer(
      overrides: [mostroDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Order order(int amount) => Order(
        id: orderId,
        kind: OrderType.sell,
        status: Status.settledHoldInvoice,
        amount: amount,
        fiatCode: 'EUR',
        fiatAmount: 710,
        paymentMethod: 'SEPA instant',
      );

  MostroMessage<Order> message(Action action, int amount, int eventCreatedAt) {
    final m = MostroMessage<Order>(
      action: action,
      id: orderId,
      payload: order(amount),
      eventCreatedAt: eventCreatedAt,
    );
    m.timestamp = eventCreatedAt;
    return m;
  }

  Future<int?> payoutAmount() async {
    final storage = container.read(mostroStorageProvider);
    final history = await storage.watchAllMessages(orderId).first;
    return latestPayoutMessage(history)?.getPayload<Order>()?.amount;
  }

  test('a newer restore reply does not replace the payout amount', () async {
    // What production stored: the payout request first, the restore reply
    // nearly two hours later, carrying the order's gross.
    await container
        .read(mostroStorageProvider)
        .addMessage('k1', message(Action.addInvoice, 935138, 1000));
    await container
        .read(mostroStorageProvider)
        .addMessage('k2', message(Action.orders, 937952, 9000));

    expect(await payoutAmount(), 935138);
  });

  // This is the one that pins the ordering: the test above would still pass
  // with the history reversed, because it holds a single payout message.
  // Confirmed by flipping the sort in MostroStorage, which fails this with
  // `Expected: <935138> Actual: <111111>`.
  test('a newer payout request wins over an older one', () async {
    await container
        .read(mostroStorageProvider)
        .addMessage('k1', message(Action.addInvoice, 111111, 1000));
    await container
        .read(mostroStorageProvider)
        .addMessage('k2', message(Action.addInvoice, 935138, 9000));

    expect(await payoutAmount(), 935138);
  });

  test('no payout message yields no amount, never another payload', () async {
    await container
        .read(mostroStorageProvider)
        .addMessage('k1', message(Action.orders, 937952, 1000));
    await container
        .read(mostroStorageProvider)
        .addMessage('k2', message(Action.buyerTookOrder, 940766, 9000));

    expect(await payoutAmount(), isNull);
  });
}
