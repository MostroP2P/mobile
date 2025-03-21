import 'dart:async';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';

class MostroStorage extends BaseStorage<MostroMessage> {
  final Logger _logger = Logger();

  MostroStorage({
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('orders'),
        );

  Future<void> init() async {
    await getAllOrders();
  }

  /// Save or update a MostroMessage
  Future<void> addOrder(MostroMessage message) async {
    final orderId = message.id;
    if (orderId == null) {
      throw ArgumentError('Cannot save an order with a null message.id');
    }

    try {
      await putItem(orderId, message);
      _logger.i('Order $orderId saved');
    } catch (e, stack) {
      _logger.e('addOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> addOrders(List<MostroMessage> orders) async {
    for (final order in orders) {
      addOrder(order);
    }
  }

  /// Retrieve an order by ID
  Future<MostroMessage?> getOrderById(String orderId) async {
    try {
      return await getItem(orderId);
    } catch (e, stack) {
      _logger.e('Error deserializing order $orderId',
          error: e, stackTrace: stack);
      return null;
    }
  }

  /// Return all orders
  Future<List<MostroMessage>> getAllOrders() async {
    try {
      return await getAllItems();
    } catch (e, stack) {
      _logger.e('getAllOrders failed', error: e, stackTrace: stack);
      return <MostroMessage>[];
    }
  }

  /// Delete an order from DB
  Future<void> deleteOrder(String orderId) async {
    try {
      await deleteItem(orderId);
      _logger.i('Order $orderId deleted from DB');
    } catch (e, stack) {
      _logger.e('deleteOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all orders
  Future<void> deleteAllOrders() async {
    try {
      await deleteAllItems();
      _logger.i('All orders deleted');
    } catch (e, stack) {
      _logger.e('deleteAllOrders failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  MostroMessage fromDbMap(String key, Map<String, dynamic> jsonMap) {
    return MostroMessage.fromJson(jsonMap);
  }

  @override
  Map<String, dynamic> toDbMap(MostroMessage item) {
    return item.toJson();
  }
}
