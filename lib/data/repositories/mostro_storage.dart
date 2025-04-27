import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';

class MostroStorage extends BaseStorage<MostroMessage> {
  final Logger _logger = Logger();

  MostroStorage({required Database db})
      : super(db, stringMapStoreFactory.store('orders'));

  // Generate a unique key for each message
  String generateMessageKey(MostroMessage message) {
    // Use orderId + action + requestId/tradeIndex or current timestamp for uniqueness
    final uniqueSuffix = message.requestId != null
        ? message.requestId.toString()
        : message.tradeIndex != null
            ? message.tradeIndex.toString()
            : DateTime.now().millisecondsSinceEpoch.toString();

    return '${message.id}_${message.action.name}_$uniqueSuffix';
  }

  /// Save or update any MostroMessage
  Future<void> addMessage(MostroMessage message) async {
    final id = generateMessageKey(message);
    try {
      // Add metadata for easier querying
      final Map<String, dynamic> dbMap = message.toJson();
      dbMap['payload_type'] = message.payload?.runtimeType.toString();
      dbMap['order_id'] = message.id;

      await store.record(id).put(db, dbMap);
      _logger.i(
        'Saved message of type ${message.payload?.runtimeType} with id $id',
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

  /// Save or update a list of MostroMessages
  Future<void> addMessages(List<MostroMessage> messages) async {
    for (final message in messages) {
      await addMessage(message);
    }
  }

  /// Retrieve a MostroMessage by ID
  Future<MostroMessage?> getMessageById<T extends Payload>(
    String orderId,
  ) async {
    final t = T;
    final id = '$t:$orderId';
    try {
      return await getItem(id);
    } catch (e, stack) {
      _logger.e('Error deserializing message $id', error: e, stackTrace: stack);
      return null;
    }
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
    try {
      final messages = await getMessagesForId(orderId);
      for (var m in messages) {
        final id = messageKey(m);
        try {
          await deleteItem(id);
          _logger.i('Message $id deleted from DB');
        } catch (e, stack) {
          _logger.e('deleteMessage failed for $id',
              error: e, stackTrace: stack);
          rethrow;
        }
      }
      _logger.i('All messages for order: $orderId deleted');
    } catch (e, stack) {
      _logger.e('deleteAllMessagesForId failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Filter messages by payload type
  Future<List<MostroMessage<T>>> getMessagesOfType<T extends Payload>() async {
    final messages = await getAllMessages();
    return messages
        .where((m) => m.payload is T)
        .map((m) => m as MostroMessage<T>)
        .toList();
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

  String messageKey(MostroMessage msg) {
    final type =
        msg.payload != null ? msg.payload.runtimeType.toString() : 'Order';
    final id = msg.id ?? msg.requestId.toString();
    return '$type:$id';
  }

  Future<bool> hasMessageByKey(String key) async {
    return hasItem(key);
  }

  /// Get the latest message for an order, regardless of type
  Future<MostroMessage?> getLatestMessageById(String orderId) async {
    final finder = Finder(filter: Filter.equals('id', orderId), limit: 1);

    final snapshot = await store.findFirst(db, finder: finder);
    if (snapshot != null) {
      return MostroMessage.fromJson(snapshot.value);
    }
    return null;
  }


  /// Stream of the latest message for an order
  Stream<MostroMessage?> watchLatestMessage(String orderId) {
    return watchById(orderId);
  }

  /// Stream of all messages for an order
  Stream<List<MostroMessage>> watchAllMessages(String orderId) {
    return watch(
      filter: Filter.equals('id', orderId),
      sort: [SortOrder('timestamp', true)],
    );
  }

  /// Stream of all messages for an order
  Stream<MostroMessage?> watchByRequestId(int requestId) {
    final query = store.query(
      finder: Finder(filter: Filter.equals('request_id', requestId)),
    );
    return query
        .onSnapshot(db)
        .map((snap) => snap == null ? null : fromDbMap('', snap.value));
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
