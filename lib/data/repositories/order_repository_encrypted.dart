import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';

/// Example (somewhat minimal) repository for storing and retrieving
/// orders in a Sembast database.
class OrderRepositoryEncrypted implements OrderRepository<MostroMessage> {
  final Logger _logger = Logger();
  final Database _database;
  final StoreRef<String, Map<String, dynamic>> _ordersStore =
      stringMapStoreFactory.store('orders');

  OrderRepositoryEncrypted(this._database);

  /// Save or update a MostroMessage (with an Order payload) in Sembast
  @override
  Future<void> addOrder(MostroMessage message) async {
    final orderId = message.id;
    if (orderId == null) {
      throw ArgumentError('Cannot save an order with a null message.id');
    }
    // Convert to JSON so we can store as a Map<String, dynamic>
    final jsonMap = message.toJson();
    await _ordersStore.record(orderId).put(_database, jsonMap);
    _logger.i('Order $orderId saved to Sembast');
  }

  /// Retrieve an order by ID
  @override
  Future<MostroMessage<Order>?> getOrderById(String orderId) async {
    final record = await _ordersStore.record(orderId).get(_database);
    if (record == null) return null;
    try {
      final msg = MostroMessage.deserialized(jsonEncode(record));
      // If the payload is indeed an Order, you can cast or do a check:
      //   final order = msg.getPayload<Order>();
      //   ...
      return msg as MostroMessage<Order>;
    } catch (e) {
      _logger.e('Error deserializing order $orderId: $e');
      return null;
    }
  }

  /// Return all orders
  @override
  Future<List<MostroMessage>> getAllOrders() async {
    final records = await _ordersStore.find(_database);
    final results = <MostroMessage<Order>>[];
    for (final record in records) {
      try {
        final msg = MostroMessage.deserialized(jsonEncode(record.value));
        results.add(msg as MostroMessage<Order>);
      } catch (e) {
        _logger.e('Error deserializing order with key ${record.key}: $e');
      }
    }
    return results;
  }

  /// Delete an order from DB
  @override
  Future<void> deleteOrder(String orderId) async {
    await _ordersStore.record(orderId).delete(_database);
  }

  /// Delete all orders
  Future<void> deleteAllOrders() async {
    await _ordersStore.delete(_database);
  }

  /// Example usage: you might have a function to update the status or action
  Future<void> updateAction(String orderId, Action newAction) async {
    final record = await _ordersStore.record(orderId).get(_database);
    if (record == null) {
      // no such order
      return;
    }
    record['order']['action'] = newAction.value;
    await _ordersStore.record(orderId).put(_database, record);
  }

  @override
  void dispose() {
    // If needed
  }

  @override
  Future<void> updateOrder(MostroMessage message) async {
    final orderId = message.id;
    if (orderId == null) {
      throw ArgumentError('Cannot save an order with a null message.id');
    }
    // Convert to JSON so we can store as a Map<String, dynamic>
    final jsonMap = message.toJson();
    await _ordersStore.record(orderId).put(_database, jsonMap);
    _logger.i('Order $orderId saved to Sembast');
  }
}
