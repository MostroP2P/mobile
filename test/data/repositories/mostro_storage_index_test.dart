import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:sembast/sembast_memory.dart';

/// Every `orders`-store write used to wake one Sembast query listener per
/// OrderNotifier and per visible trade row, each re-filtering the whole
/// unindexed store on the UI isolate: O((notifiers + rows) × messages) per
/// incoming message. The storage now keeps a single in-memory index by order
/// id; watchers are served from it and Sembast remains the persistence
/// layer, warmed once per cold start.
void main() {
  late MostroStorage storage;

  MostroMessage message(String orderId, Action action, int timestamp) {
    final m = MostroMessage(action: action, id: orderId);
    m.timestamp = timestamp;
    return m;
  }

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('index_test.db');
    storage = MostroStorage(db: db);
  });

  test('the latest-message watcher tracks adds for its order', () async {
    final emissions = <MostroMessage?>[];
    final sub = storage.watchLatestMessage('a').listen(emissions.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    await storage.addMessage('k2', message('a', Action.payInvoice, 2000));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions.last!.action, Action.payInvoice);
  });

  test('a write for another order does not notify this watcher', () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    var emissions = 0;
    final sub = storage.watchLatestMessage('a').skip(1).listen((_) {
      emissions++;
    });
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await storage.addMessage('k2', message('b', Action.newOrder, 2000));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions, 0,
        reason: 'per-order streams must be demultiplexed in memory');
  });

  test('history is served newest-first and per order', () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    await storage.addMessage('k2', message('a', Action.payInvoice, 3000));
    await storage.addMessage('k3', message('b', Action.newOrder, 2000));

    final history = await storage.getAllMessagesForOrderId('a');

    expect(history.map((m) => m.action),
        [Action.payInvoice, Action.newOrder]);
    expect(await storage.getLatestMessageById('b'),
        isA<MostroMessage>().having((m) => m.id, 'id', 'b'));
  });

  test('a cold start warms the index from disk', () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));

    // New storage over the same database: what a restart looks like.
    final restarted = MostroStorage(db: storage.db);
    final latest = await restarted.getLatestMessageById('a');

    expect(latest!.action, Action.newOrder);
    expect(restarted.debugIndexSize, greaterThan(0));
  });

  test('deleting an order clears it from index and watchers', () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    final emissions = <MostroMessage?>[];
    final sub = storage.watchLatestMessage('a').listen(emissions.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await storage.deleteAllMessagesByOrderId('a');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions.last, isNull);
    expect(await storage.getAllMessagesForOrderId('a'), isEmpty);
  });

  test('deleteAll clears the index, not just the disk', () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    await storage.addMessage('k2', message('a', Action.payInvoice, 2000));
    final emissions = <MostroMessage?>[];
    final sub = storage.watchLatestMessage('a').listen(emissions.add);
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    // The wipe-everything flows (account restore, master-key rotation) call
    // the inherited deleteAll(), not deleteAllMessages().
    await storage.deleteAll();
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(await storage.getLatestMessageById('a'), isNull);
    expect(await storage.getAllMessagesForOrderId('a'), isEmpty);
    expect(storage.debugIndexSize, 0);
    expect(emissions.last, isNull);
  });

  test('a restore does not merge pre-wipe history into the restored order',
      () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    await storage.addMessage('k2', message('a', Action.payInvoice, 2000));

    // What restore_manager does: wipe, then re-add the restored messages.
    await storage.deleteAll();
    await storage.addMessage('k3', message('a', Action.newOrder, 3000));

    final history = await storage.getAllMessagesForOrderId('a');
    expect(history.map((m) => m.action), [Action.newOrder]);
  });

  test('a failed warm-up is retried instead of poisoning every query',
      () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    final flaky = _FlakyWarmupStorage(db: storage.db);

    await expectLater(
        flaky.getLatestMessageById('a'), throwsA(isA<StateError>()));

    // A retained failed future would rethrow here for the rest of the session.
    expect((await flaky.getLatestMessageById('a'))!.action, Action.newOrder);
  });

  test('concurrent writes of the same key index the message once', () async {
    await Future.wait([
      storage.addMessage('k1', message('a', Action.newOrder, 1000)),
      storage.addMessage('k1', message('a', Action.newOrder, 1000)),
    ]);

    expect((await storage.getAllMessagesForOrderId('a')).length, 1);
  });

  test('duplicate keys are ignored without notifying watchers twice',
      () async {
    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    var emissions = 0;
    final sub = storage.watchLatestMessage('a').skip(1).listen((_) {
      emissions++;
    });
    addTearDown(sub.cancel);
    await Future<void>.delayed(const Duration(milliseconds: 20));

    await storage.addMessage('k1', message('a', Action.newOrder, 1000));
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(emissions, 0);
  });
}

/// Fails the first index warm-up read, then behaves normally.
class _FlakyWarmupStorage extends MostroStorage {
  _FlakyWarmupStorage({required super.db});

  int _failuresLeft = 1;

  @override
  Future<List<MostroMessage>> getAll() {
    if (_failuresLeft-- > 0) {
      return Future.error(StateError('transient read failure'));
    }
    return super.getAll();
  }
}
