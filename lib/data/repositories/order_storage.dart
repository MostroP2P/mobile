import 'dart:async';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

class OrderStorage extends BaseStorage<Order> {
  final Logger _logger = Logger();

  OrderStorage({
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('orders'),
        );

  Future<void> init() async {
    await getAllOrders();
  }

  /// Save or update an Order
  Future<void> addOrder(Order order) async {
    final orderId = order.id;
    if (orderId == null) {
      throw ArgumentError('Cannot save an order with a null order.id');
    }

    try {
      await putItem(orderId, order);
      _logger.i('Order $orderId saved');
    } catch (e, stack) {
      _logger.e('addOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  Future<void> addOrders(List<Order> orders) async {
    for (final order in orders) {
      addOrder(order);
    }
  }

  /// Retrieve an order by ID
  Future<Order?> getOrderById(String orderId) async {
    try {
      return await getItem(orderId);
    } catch (e, stack) {
      _logger.e('Error deserializing order $orderId',
          error: e, stackTrace: stack);
      return null;
    }
  }

  /// Return all orders
  Future<List<Order>> getAllOrders() async {
    try {
      return await getAllItems();
    } catch (e, stack) {
      _logger.e('getAllOrders failed', error: e, stackTrace: stack);
      return <Order>[];
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
  Order fromDbMap(String key, Map<String, dynamic> jsonMap) {
    return Order.fromJson(jsonMap);
  }

  @override
  Map<String, dynamic> toDbMap(Order item) {
    return item.toJson();
  }
}
