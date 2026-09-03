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
  final NotificationsRepository notificationsStorage;

  /// Floor for reservation retention. It is only a floor: the orders filter
  /// carries no `since`, so a relay may re-deliver any event a live session's
  /// trade key matches, and the reservation is the only dedup for Mostro DMs.
  /// An event for a live session cannot predate that session, so the real
  /// cutoff is the older of this window and the oldest live session's start.
  static const Duration reservationRetention = Duration(days: 7);

  /// A full scan of both stores on the main isolate is not worth paying at
  /// every session-cleanup tick; storage growth is a slow process.
  static const Duration minimumInterval = Duration(hours: 6);

  /// Orphaned records (no live session) get a grace window before deletion
  /// so a restore in progress is never raced.
  static const Duration orphanRetention = Duration(days: 30);

  static const int notificationCap = 300;

  /// Timestamps below this are seconds, above are milliseconds (the boundary
  /// sits in the year 33658 for seconds and 2001 for milliseconds).
  static const int _millisecondThreshold = 1000000000000;

  DateTime? _lastRunAt;

  /// Errors propagate: a pruner that silently stopped working would keep the
  /// growth it exists to bound.
  Future<void> prune({
    required Set<String> liveOrderIds,
    required Set<String> liveDisputeIds,
    DateTime? oldestLiveSessionAt,
    DateTime? now,
  }) async {
    final at = now ?? DateTime.now();
    final last = _lastRunAt;
    if (last != null && at.difference(last) < minimumInterval) return;
    _lastRunAt = at;
    await _pruneReservations(at, oldestLiveSessionAt);
    await _pruneOrphanEvents(at, liveOrderIds, liveDisputeIds);
    await _pruneOrphanMessages(at, liveOrderIds);
    await _capNotifications();
  }

  Future<void> _pruneReservations(
    DateTime now,
    DateTime? oldestLiveSessionAt,
  ) async {
    var cutoffAt = now.subtract(reservationRetention);
    if (oldestLiveSessionAt != null && oldestLiveSessionAt.isBefore(cutoffAt)) {
      // Keep every reservation a live session could still see replayed.
      cutoffAt = oldestLiveSessionAt;
    }
    final cutoff = cutoffAt.millisecondsSinceEpoch ~/ 1000;
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
    final cutoff = now.subtract(orphanRetention).millisecondsSinceEpoch ~/ 1000;
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
      // The daemon sends seconds, the app fills in milliseconds when the
      // field is absent, and both units coexist in the store. The index
      // orders on the raw field, where any millisecond value outranks any
      // seconds value regardless of real time, so the newest record is picked
      // here on normalized timestamps. An unknown or non-positive timestamp
      // is never treated as proof of age.
      int? newest;
      for (final message
          in await messageStorage.getAllMessagesForOrderId(orderId)) {
        final ts = _timestampMs(message.timestamp);
        if (ts != null && (newest == null || ts > newest)) newest = ts;
      }
      if (newest != null && newest < cutoffMs) {
        await messageStorage.deleteAllMessagesByOrderId(orderId);
        logger.i('Pruned orphaned messages for order $orderId');
      }
    }
  }

  Future<void> _capNotifications() async {
    final all = await notificationsStorage.getAllNotifications();
    if (all.length <= notificationCap) return;
    // Deleting the exact overflow entries rather than everything older than
    // the cap-th timestamp: a burst of tied timestamps would otherwise leave
    // the history above the cap on every pass.
    final sorted = [...all]..sort((a, b) {
        final byTime = b.timestamp.compareTo(a.timestamp);
        return byTime != 0 ? byTime : b.id.compareTo(a.id);
      });
    final overflow = sorted.skip(notificationCap).map((n) => n.id);
    final removed = await notificationsStorage.deleteByIds(overflow);
    _logRemoved('old notifications', removed);
  }

  static int? _timestampMs(int? raw) {
    if (raw == null || raw <= 0) return null;
    return raw < _millisecondThreshold ? raw * 1000 : raw;
  }

  void _logRemoved(String what, Object? removed) {
    logger.i('Storage pruner: removed $what ($removed)');
  }
}
