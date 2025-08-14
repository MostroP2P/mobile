import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:mostro_mobile/data/models/restore_session_payload.dart';

class MostroStorage extends BaseStorage<MostroMessage> {
  final Logger _logger = Logger();

  MostroStorage({required Database db})
      : super(db, stringMapStoreFactory.store('orders'));

  /// Save or update any MostroMessage
  Future<void> addMessage(String key, MostroMessage message) async {
    final id = key;
    try {
      if (await hasItem(id)) return;
      // Add metadata for easier querying
      final Map<String, dynamic> dbMap = message.toJson();
      if (message.timestamp == null) {
        message.timestamp = DateTime.now().millisecondsSinceEpoch;
      }
      dbMap['timestamp'] = message.timestamp;

      await store.record(id).put(db, dbMap);
      _logger.i(
        'Saved message of type ${message.action} with order id ${message.id}',
      );
    } catch (e, stack) {
      _logger.e(
        'addMessage failed for $id',
        error: e,
        stackTrace: stack,
      );
      rethrow;
    }
  }

  /// Stream the latest restore-session payload message if present
  Stream<MostroMessage?> watchLatestRestorePayload() {
    final query = store.query(
      finder: Finder(
        sortOrders: _getDefaultSort(),
      ),
    );

    return query.onSnapshots(db).map((snaps) {
      for (final snap in snaps) {
        final msg = MostroMessage.fromJson(snap.value);
        if (msg.payload is RestoreSessionPayload) {
          return msg;
        }
      }
      return null;
    });
  }

  /// Get all messages
  Future<List<MostroMessage>> getAllMessages() async {
    try {
      return await getAll();
    } catch (e, stack) {
      _logger.e('getAllMessages failed', error: e, stackTrace: stack);
      return <MostroMessage>[];
    }
  }

  /// Delete all messages
  Future<void> deleteAllMessages() async {
    try {
      await deleteAll();
      _logger.i('All messages deleted');
    } catch (e, stack) {
      _logger.e('deleteAllMessages failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all messages by Id regardless of type
  Future<void> deleteAllMessagesByOrderId(String orderId) async {
    await deleteWhere(
      Filter.equals('id', orderId),
    );
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
    final finder = Finder(
      filter: Filter.equals('id', orderId),
      sortOrders: _getDefaultSort(),
      limit: 1,
    );

    final snapshot = await store.findFirst(db, finder: finder);
    if (snapshot != null) {
      return MostroMessage.fromJson(snapshot.value);
    }
    return null;
  }

  /// Stream of the latest message for an order
  Stream<MostroMessage?> watchLatestMessage(String orderId) {
    final query = store.query(
      finder: Finder(
        filter: Filter.equals('id', orderId),
        sortOrders: _getDefaultSort(),
        limit: 1,
      ),
    );

    return query.onSnapshots(db).map((snaps) =>
        snaps.isEmpty ? null : MostroMessage.fromJson(snaps.first.value));
  }

  /// Stream of the latest message for an order whose payload is of type T
  Stream<MostroMessage?> watchLatestMessageOfType<T>(String orderId) {
    // Watch all messages for the orderId, sorted by timestamp descending
    final query = store.query(
      finder: Finder(
        filter: Filter.equals('id', orderId),
        sortOrders: _getDefaultSort(),
      ),
    );
    return query.onSnapshots(db).map((snaps) {
      for (final snap in snaps) {
        final msg = MostroMessage.fromJson(snap.value);
        if (msg.payload is T) {
          return msg;
        }
      }
      return null;
    });
  }

  // Use the same sorting across all methods that return lists of messages
  List<SortOrder> _getDefaultSort() => [SortOrder('timestamp', false, true)];

  /// Stream of all messages for an order
  Stream<List<MostroMessage>> watchAllMessages(String orderId) {
    return watch(
      filter: Filter.equals('id', orderId),
      sort: _getDefaultSort(),
    );
  }

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
    final finder = Finder(
        filter: Filter.equals('id', orderId),
        sortOrders: [SortOrder('timestamp', false)]);

    final snapshots = await store.find(db, finder: finder);
    return snapshots
        .map((snapshot) => MostroMessage.fromJson(snapshot.value))
        .toList();
  }
}
