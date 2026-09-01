import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';

class MostroStorage extends BaseStorage<MostroMessage> {
  MostroStorage({required Database db})
      : super(db, stringMapStoreFactory.store('orders'));

  /// In-memory index by order id (newest first). Every write used to wake
  /// one Sembast query listener per OrderNotifier and per visible trade row,
  /// each re-filtering the whole unindexed store on the UI isolate. The
  /// index is warmed from disk once; watchers are served from memory and
  /// demultiplexed per order.
  final Map<String, List<MostroMessage>> _byOrder = {};
  final StreamController<String> _orderChanges = StreamController.broadcast();
  Future<void>? _warmup;

  @visibleForTesting
  int get debugIndexSize => _byOrder.length;

  /// Order ids currently holding messages (index-backed).
  Future<List<String>> allOrderIds() async {
    await _ensureIndex();
    return _byOrder.keys.toList(growable: false);
  }

  Future<void> _ensureIndex() {
    return _warmup ??= () async {
      final all = await getAll();
      for (final message in all) {
        _indexAdd(message, notify: false);
      }
      logger.i('Mostro message index warmed: ${_byOrder.length} orders');
    }();
  }

  void _indexAdd(MostroMessage message, {bool notify = true}) {
    final orderId = message.id;
    if (orderId == null) return;
    final list = _byOrder.putIfAbsent(orderId, () => <MostroMessage>[]);
    list.add(message);
    list.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    if (notify) _notifyOrder(orderId);
  }

  void _notifyOrder(String orderId) {
    if (!_orderChanges.isClosed) _orderChanges.add(orderId);
  }

  MostroMessage? _latestFor(String orderId) {
    final list = _byOrder[orderId];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  List<MostroMessage> _historyFor(String orderId) =>
      List.unmodifiable(_byOrder[orderId] ?? const <MostroMessage>[]);

  Stream<R> _watchOrder<R>(String orderId, R Function() read) {
    late StreamController<R> controller;
    StreamSubscription<String>? changes;
    controller = StreamController<R>(
      onListen: () async {
        await _ensureIndex();
        if (controller.isClosed) return;
        controller.add(read());
        changes = _orderChanges.stream
            .where((changed) => changed == orderId)
            .listen((_) => controller.add(read()));
      },
      onCancel: () async {
        await changes?.cancel();
        await controller.close();
      },
    );
    return controller.stream;
  }

  /// Save or update any MostroMessage
  Future<void> addMessage(String key, MostroMessage message) async {
    final id = key;
    try {
      await _ensureIndex();
      if (await hasItem(id)) return;
      // Add metadata for easier querying
      final Map<String, dynamic> dbMap = message.toJson();
      message.timestamp ??= DateTime.now().millisecondsSinceEpoch;
      dbMap['timestamp'] = message.timestamp;

      await store.record(id).put(db, dbMap);
      _indexAdd(message);
      logger.i(
        'Saved message of type ${message.action} with order id ${message.id}',
      );
    } catch (e, stack) {
      logger.e(
        'addMessage failed for $id',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Get all messages
  Future<List<MostroMessage>> getAllMessages() async {
    try {
      return await getAll();
    } catch (e, stack) {
      logger.e('getAllMessages failed', error: e, stackTrace: stack);
      return <MostroMessage>[];
    }
  }

  /// Delete all messages
  Future<void> deleteAllMessages() async {
    try {
      await _ensureIndex();
      await deleteAll();
      final orderIds = _byOrder.keys.toList();
      _byOrder.clear();
      orderIds.forEach(_notifyOrder);
      logger.i('All messages deleted');
    } catch (e, stack) {
      logger.e('deleteAllMessages failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all messages by Id regardless of type
  Future<void> deleteAllMessagesByOrderId(String orderId) async {
    await _ensureIndex();
    await deleteWhere(
      Filter.equals('id', orderId),
    );
    _byOrder.remove(orderId);
    _notifyOrder(orderId);
  }

  /// Filter messages by payload type
  Future<List<MostroMessage>> getMessagesOfType<T extends Payload>() async {
    final messages = await getAllMessages();
    return messages
        .where((m) => m.payload is T)
        .map((m) => m as MostroMessage<T>)
        .toList();
  }

  /// Filter messages by payload type
  Future<MostroMessage?> getLatestMessageOfTypeById<T extends Payload>(
    String orderId,
  ) async {
    final messages = await getMessagesForId(orderId);
    for (final message in messages.reversed) {
      if (message.payload is T) {
        return message;
      }
    }
    return null;
  }

  /// Filter messages by tradeKeyPublic
  Future<List<MostroMessage>> getMessagesForId(String orderId) async {
    final messages = await getAllMessages();
    return messages.where((m) => m.id == orderId).toList();
  }

  @override
  MostroMessage fromDbMap(String key, Map<String, dynamic> jsonMap) {
    return MostroMessage.fromJson(jsonMap);
  }

  @override
  Map<String, dynamic> toDbMap(MostroMessage item) {
    return item.toJson();
  }

  Future<bool> hasMessageByKey(String key) async {
    return hasItem(key);
  }

  /// Get the latest message for an order, regardless of type
  Future<MostroMessage?> getLatestMessageById(String orderId) async {
    await _ensureIndex();
    return _latestFor(orderId);
  }

  /// Stream of the latest message for an order
  Stream<MostroMessage?> watchLatestMessage(String orderId) =>
      _watchOrder(orderId, () => _latestFor(orderId));

  /// Stream of the latest message for an order whose payload is of type T
  Stream<MostroMessage?> watchLatestMessageOfType<T>(String orderId) =>
      _watchOrder(orderId, () {
        for (final message in _byOrder[orderId] ?? const <MostroMessage>[]) {
          if (message.payload is T) return message;
        }
        return null;
      });

  /// Stream of all messages for an order (newest first)
  Stream<List<MostroMessage>> watchAllMessages(String orderId) =>
      _watchOrder(orderId, () => _historyFor(orderId));

  // Sorting for the remaining DB-backed query (request-id lookups are
  // transient one-offs during order creation and stay on Sembast).
  List<SortOrder> _getDefaultSort() => [SortOrder('timestamp', false, true)];

  Stream<MostroMessage?> watchByRequestId(int requestId) {
    final query = store.query(
      finder: Finder(
        filter: Filter.equals('request_id', requestId),
        sortOrders: _getDefaultSort(),
        limit: 1,
      ),
    );

    return query.onSnapshots(db).map((snapshots) =>
        snapshots.isNotEmpty ? MostroMessage.fromJson(snapshots.first.value) : null);
  }

  Future<List<MostroMessage>> getAllMessagesForOrderId(String orderId) async {
    await _ensureIndex();
    return _historyFor(orderId);
  }
}
