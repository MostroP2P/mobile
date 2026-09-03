import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/notification.dart';
import 'package:mostro_mobile/data/models/enums/notification_type.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/services/storage_pruner.dart';
import 'package:sembast/sembast_memory.dart';

/// Both databases are fully loaded into RAM and JSON-parsed at every launch,
/// and three record families grew without bound: DM reservation records
/// ({id, created_at}, no order_id — unreachable by the session cleanup),
/// chat/message records for orders whose session is gone, and the
/// notification history. In "keep forever" mode nothing pruned at all.
void main() {
  late EventStorage events;
  late MostroStorage messages;
  late NotificationsStorage notifications;
  late StoragePruner pruner;
  final now = DateTime.now();

  int secsAgo(Duration d) => now.subtract(d).millisecondsSinceEpoch ~/ 1000;

  setUp(() async {
    final db = await newDatabaseFactoryMemory().openDatabase('pruner.db');
    events = EventStorage(db: db);
    messages = MostroStorage(db: db);
    notifications = NotificationsStorage(db: db);
    pruner = StoragePruner(
      eventStorage: events,
      messageStorage: messages,
      notificationsStorage: notifications,
    );
  });

  test('expired DM reservations are deleted, fresh ones stay', () async {
    await events.putItem('old-res', {
      'id': 'old-res',
      'created_at': secsAgo(const Duration(days: 8)),
    });
    await events.putItem('fresh-res', {
      'id': 'fresh-res',
      'created_at': secsAgo(const Duration(hours: 1)),
    });

    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);

    expect(await events.hasItem('old-res'), isFalse);
    expect(await events.hasItem('fresh-res'), isTrue);
  });

  test('reservations a live session could still see replayed are kept',
      () async {
    // The orders filter carries no `since`, and the reservation is the only
    // dedup for Mostro DMs: anything the oldest live session could match must
    // survive the 7-day floor.
    await events.putItem('within-session', {
      'id': 'within-session',
      'created_at': secsAgo(const Duration(days: 20)),
    });
    await events.putItem('before-session', {
      'id': 'before-session',
      'created_at': secsAgo(const Duration(days: 40)),
    });

    await pruner.prune(
      liveOrderIds: {},
      liveDisputeIds: {},
      oldestLiveSessionAt: now.subtract(const Duration(days: 30)),
      now: now,
    );

    expect(await events.hasItem('within-session'), isTrue,
        reason: 'a live session predates it: replay is still possible');
    expect(await events.hasItem('before-session'), isFalse);
  });

  test('a seconds timestamp still gets the full grace window', () async {
    // The daemon sends seconds; the app only fills in milliseconds when the
    // field is absent, so both units coexist in the store.
    final today = MostroMessage(action: Action.newOrder, id: 'dead-order');
    today.timestamp = now.millisecondsSinceEpoch ~/ 1000;
    await messages.addMessage('m1', today);

    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);

    expect(await messages.getAllMessagesForOrderId('dead-order'), hasLength(1),
        reason: 'the message was written today; the grace window protects it');
  });

  test('tied notification timestamps do not defeat the cap', () async {
    final tied = now.subtract(const Duration(days: 1));
    for (var i = 0; i < StoragePruner.notificationCap + 20; i++) {
      await notifications.addNotification(NotificationModel(
        id: 'n$i',
        type: NotificationType.system,
        action: Action.newOrder,
        title: 't$i',
        message: 'm$i',
        timestamp: tied,
      ));
    }

    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);

    expect(
        await notifications.getAll(), hasLength(StoragePruner.notificationCap));
  });

  test('a second pass within the minimum interval is skipped', () async {
    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);
    await events.putItem('old-res', {
      'id': 'old-res',
      'created_at': secsAgo(const Duration(days: 8)),
    });

    await pruner.prune(
      liveOrderIds: {},
      liveDisputeIds: {},
      now: now.add(const Duration(minutes: 30)),
    );
    expect(await events.hasItem('old-res'), isTrue,
        reason: 'a full scan of both stores is not paid at every tick');

    await pruner.prune(
      liveOrderIds: {},
      liveDisputeIds: {},
      now: now.add(StoragePruner.minimumInterval),
    );
    expect(await events.hasItem('old-res'), isFalse);
  });

  test('old chat events survive only while their order has a session',
      () async {
    await events.putItem('dead-chat', {
      'id': 'dead-chat',
      'type': 'chat',
      'order_id': 'dead-order',
      'created_at': secsAgo(const Duration(days: 40)),
    });
    await events.putItem('live-chat', {
      'id': 'live-chat',
      'type': 'chat',
      'order_id': 'live-order',
      'created_at': secsAgo(const Duration(days: 40)),
    });
    await events.putItem('recent-orphan', {
      'id': 'recent-orphan',
      'type': 'chat',
      'order_id': 'dead-order',
      'created_at': secsAgo(const Duration(days: 1)),
    });

    await pruner.prune(
      liveOrderIds: {'live-order'},
      liveDisputeIds: {},
      now: now,
    );

    expect(await events.hasItem('dead-chat'), isFalse,
        reason: 'orphaned and older than the retention window');
    expect(await events.hasItem('live-chat'), isTrue);
    expect(await events.hasItem('recent-orphan'), isTrue,
        reason: 'recent orphans wait: the session may still be restoring');
  });

  test('orphaned mostro messages are pruned through the storage index',
      () async {
    final old = MostroMessage(action: Action.newOrder, id: 'dead-order');
    old.timestamp =
        now.subtract(const Duration(days: 40)).millisecondsSinceEpoch;
    await messages.addMessage('m1', old);
    final live = MostroMessage(action: Action.newOrder, id: 'live-order');
    live.timestamp = now.millisecondsSinceEpoch;
    await messages.addMessage('m2', live);

    await pruner.prune(
      liveOrderIds: {'live-order'},
      liveDisputeIds: {},
      now: now,
    );

    expect(await messages.getAllMessagesForOrderId('dead-order'), isEmpty);
    expect(await messages.getAllMessagesForOrderId('live-order'), hasLength(1));
  });

  test('a fresh seconds record protects an order whose older record is in ms',
      () async {
    // Both units coexist in `timestamp`. A raw sort ranks any millisecond
    // value above any seconds value regardless of real time, so "the latest
    // message" must be chosen on normalized timestamps or a 40-day-old ms
    // record would count as newer than a seconds record written today.
    final old = MostroMessage(action: Action.newOrder, id: 'mixed-order');
    old.timestamp =
        now.subtract(const Duration(days: 40)).millisecondsSinceEpoch;
    await messages.addMessage('m1', old);
    final fresh = MostroMessage(action: Action.payInvoice, id: 'mixed-order');
    fresh.timestamp = now.millisecondsSinceEpoch ~/ 1000;
    await messages.addMessage('m2', fresh);

    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);

    expect(await messages.getAllMessagesForOrderId('mixed-order'), hasLength(2),
        reason: 'the newest record is from today, so nothing is orphaned');
  });

  test('the notification history is capped to the newest entries', () async {
    for (var i = 0; i < StoragePruner.notificationCap + 20; i++) {
      await notifications.addNotification(NotificationModel(
        id: 'n$i',
        type: NotificationType.system,
        action: Action.newOrder,
        title: 't$i',
        message: 'm$i',
        timestamp: now.subtract(Duration(minutes: i)),
      ));
    }

    await pruner.prune(liveOrderIds: {}, liveDisputeIds: {}, now: now);

    final remaining = await notifications.getAll();
    expect(remaining, hasLength(StoragePruner.notificationCap));
    expect(remaining.map((n) => n.id), contains('n0'));
    expect(remaining.map((n) => n.id),
        isNot(contains('n${StoragePruner.notificationCap + 19}')));
  });
}
