import 'dart:async';
import 'dart:convert';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';

class MostroStorage implements OrderRepository<MostroMessage> {
  final Logger _logger = Logger();
  final Database _database;

  /// In-memory cache for quick lookups.
  final Map<String, MostroMessage> _messages = {};

  final StoreRef<String, Map<String, dynamic>> _ordersStore =
      stringMapStoreFactory.store('orders');

  MostroStorage(this._database);

  Future<void> init() async {
    await getAllOrders();
  }

  /// Save or update a MostroMessage
  @override
  Future<void> addOrder(MostroMessage message) async {
    final orderId = message.id;
    if (orderId == null) {
      throw ArgumentError('Cannot save an order with a null message.id');
    }

    try {
      await _database.transaction((txn) async {
        final jsonMap = message.toJson();
        await _ordersStore.record(orderId).put(txn, jsonMap);
      });

      // Update in-memory cache
      _messages[orderId] = message;
      _logger.i('Order $orderId saved to Sembast');
    } catch (e, stack) {
      _logger.e('addOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow; // Rethrow or handle the error as needed
    }
  }

  Future<void> addOrders(List<MostroMessage> orders) async {
    for (final order in orders) {
      addOrder(order);
    }
  }

  /// Retrieve an order by ID
  @override
  Future<MostroMessage?> getOrderById(String orderId) async {
    // First check in-memory cache
    if (_messages.containsKey(orderId)) {
      return _messages[orderId];
    }

    try {
      final record = await _ordersStore.record(orderId).get(_database);
      if (record == null) {
        return null;
      }
      final msg = MostroMessage.deserialized(jsonEncode(record));
      // Update in-memory cache
      _messages[orderId] = msg;
      return msg;
    } catch (e, stack) {
      _logger.e('Error deserializing order $orderId',
          error: e, stackTrace: stack);
      return null;
    }
  }

  /// Return all orders
  @override
  Future<List<MostroMessage>> getAllOrders() async {
    try {
      final records = await _ordersStore.find(_database);
      final results = <MostroMessage>[];
      for (final record in records) {
        try {
          final msg = MostroMessage.deserialized(jsonEncode(record.value));
          results.add(msg);
          // Update or populate in-memory cache
          _messages[record.key] = msg;
        } catch (e, stack) {
          _logger.e('Error deserializing order with key ${record.key}',
              error: e, stackTrace: stack);
        }
      }
      return results;
    } catch (e, stack) {
      _logger.e('getAllOrders failed', error: e, stackTrace: stack);
      return <MostroMessage>[];
    }
  }

  /// Delete an order from DB
  @override
  Future<void> deleteOrder(String orderId) async {
    try {
      await _database.transaction((txn) async {
        await _ordersStore.record(orderId).delete(txn);
      });
      _messages.remove(orderId);
      _logger.i('Order $orderId deleted from DB');
    } catch (e, stack) {
      _logger.e('deleteOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Delete all orders
  Future<void> deleteAllOrders() async {
    try {
      await _database.transaction((txn) async {
        await _ordersStore.delete(txn);
      });
      _messages.clear();
      _logger.i('All orders deleted');
    } catch (e, stack) {
      _logger.e('deleteAllOrders failed', error: e, stackTrace: stack);
      rethrow;
    }
  }

  /// Update an entire order
  @override
  Future<void> updateOrder(MostroMessage message) async {
    final orderId = message.id;
    if (orderId == null) {
      throw ArgumentError('Cannot update an order with a null message.id');
    }

    try {
      await _database.transaction((txn) async {
        final jsonMap = message.toJson();
        await _ordersStore.record(orderId).put(txn, jsonMap);
      });
      // Update in-memory cache
      _messages[orderId] = message;
      _logger.i('Order $orderId updated in Sembast');
    } catch (e, stack) {
      _logger.e('updateOrder failed for $orderId', error: e, stackTrace: stack);
      rethrow;
    }
  }

  @override
  void dispose() {
    // await _database.close();
  }
}
