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
    old.timestamp = now
        .subtract(const Duration(days: 40))
        .millisecondsSinceEpoch;
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
    expect(await messages.getAllMessagesForOrderId('live-order'),
        hasLength(1));
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
