import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';

class MostroStorage extends BaseStorage<MostroMessage> {
  final Logger _logger = Logger();

  MostroStorage({required Database db})
      : super(db, stringMapStoreFactory.store('orders'));

  /// Save or update any MostroMessage
  Future<void> addMessage(MostroMessage message) async {
    final id = messageKey(message);
    try {
      await putItem(id, message);
      _logger.i(
          'Saved message of type \${message.payload.runtimeType} with id \$id');
    } catch (e, stack) {
      _logger.e(
        'addMessage failed for \$id',
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
      _logger.e('Error deserializing message \$id',
          error: e, stackTrace: stack);
      return null;
    }
  }

  /// Get all messages
  Future<List<MostroMessage>> getAllMessages() async {
    try {
      return await getAllItems();
    } catch (e, stack) {
      _logger.e('getAllMessages failed', error: e, stackTrace: stack);
      return <MostroMessage>[];
    }
  }

  /// Delete a message by ID
  Future<void> deleteMessage<T extends Payload>(String orderId) async {
    final id = '${T.runtimeType}:$orderId';
    try {
      await deleteItem(id);
      _logger.i('Message \$id deleted from DB');
    } catch (e, stack) {
      _logger.e('deleteMessage failed for \$id', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all messages
  Future<void> deleteAllMessages() async {
    try {
      await deleteAllItems();
      _logger.i('All messages deleted');
    } catch (e, stack) {
      _logger.e('deleteAllMessages failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all messages by Id regardless of type
  Future<void> deleteAllMessagesById(String orderId) async {
    try {
      final messages = await getMessagesForId(orderId);
      for (var m in messages) {
        final id = messageKey(m);
        try {
          await deleteItem(id);
          _logger.i('Message \$id deleted from DB');
        } catch (e, stack) {
          _logger.e('deleteMessage failed for \$id',
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
}
