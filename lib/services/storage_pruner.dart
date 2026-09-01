import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/data/repositories/notifications_history_repository.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:sembast/sembast.dart';

/// Bounded growth for the local databases.
///
/// Both Sembast files are fully loaded into RAM and JSON-parsed at every
/// launch, so unbounded growth taxes every cold start and every store scan.
/// Three families grew forever: DM reservation records ({id, created_at},
/// no order_id — unreachable by the session cleanup), chat/message records
/// for orders whose session is gone, and the notification history. In
/// "keep forever" session mode nothing pruned at all.
class StoragePruner {
  StoragePruner({
    required this.eventStorage,
    required this.messageStorage,
    required this.notificationsStorage,
  });

  final EventStorage eventStorage;
  final MostroStorage messageStorage;
  final NotificationsStorage notificationsStorage;

  /// Reservations only guard replay dedup within the subscription's since
  /// window; anything older than the widest lookback is dead weight.
  static const Duration reservationRetention = Duration(days: 7);

  /// Orphaned records (no live session) get a grace window before deletion
  /// so a restore in progress is never raced.
  static const Duration orphanRetention = Duration(days: 30);

  static const int notificationCap = 300;

  Future<void> prune({
    required Set<String> liveOrderIds,
    required Set<String> liveDisputeIds,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    try {
      await _pruneReservations(at);
      await _pruneOrphanEvents(at, liveOrderIds, liveDisputeIds);
      await _pruneOrphanMessages(at, liveOrderIds);
      await _capNotifications();
    } catch (e, stackTrace) {
      logger.e('Storage pruning failed', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> _pruneReservations(DateTime now) async {
    final cutoff =
        now.subtract(reservationRetention).millisecondsSinceEpoch ~/ 1000;
    final removed = await eventStorage.deleteWhere(Filter.and([
      Filter.isNull('type'),
      Filter.lessThan('created_at', cutoff),
    ]));
    _logRemoved('DM reservations', removed);
  }

  Future<void> _pruneOrphanEvents(
    DateTime now,
    Set<String> liveOrderIds,
    Set<String> liveDisputeIds,
  ) async {
    final cutoff =
        now.subtract(orphanRetention).millisecondsSinceEpoch ~/ 1000;
    final removed = await eventStorage.deleteWhere(Filter.custom((record) {
      final value = record.value;
      if (value is! Map) return false;
      final type = value['type'];
      if (type != 'chat' && type != 'dispute_chat') return false;
      final createdAt = value['created_at'];
      if (createdAt is! int || createdAt >= cutoff) return false;
      if (type == 'chat') {
        return !liveOrderIds.contains(value['order_id']);
      }
      return !liveDisputeIds.contains(value['dispute_id']);
    }));
    _logRemoved('orphaned chat events', removed);
  }

  Future<void> _pruneOrphanMessages(
    DateTime now,
    Set<String> liveOrderIds,
  ) async {
    final cutoffMs = now.subtract(orphanRetention).millisecondsSinceEpoch;
    // Through the storage API so the in-memory index stays coherent.
    for (final orderId in await messageStorage.allOrderIds()) {
      if (liveOrderIds.contains(orderId)) continue;
      final latest = await messageStorage.getLatestMessageById(orderId);
      final ts = latest?.timestamp;
      if (ts != null && ts < cutoffMs) {
        await messageStorage.deleteAllMessagesByOrderId(orderId);
        logger.i('Pruned orphaned messages for order $orderId');
      }
    }
  }

  Future<void> _capNotifications() async {
    final all = await notificationsStorage.getAll();
    if (all.length <= notificationCap) return;
    final sorted = [...all]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final cutoff = sorted[notificationCap - 1].timestamp;
    final removed = await notificationsStorage.deleteWhere(
      Filter.custom((record) {
        final value = record.value;
        if (value is! Map) return false;
        final raw = value['timestamp'];
        if (raw is! String) return false;
        final ts = DateTime.tryParse(raw);
        return ts != null && ts.isBefore(cutoff);
      }),
    );
    _logRemoved('old notifications', removed);
  }

  void _logRemoved(String what, Object? removed) {
    logger.i('Storage pruner: removed $what ($removed)');
  }
}
