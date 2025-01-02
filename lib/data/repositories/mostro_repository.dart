import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroRepository implements OrderRepository {
  final MostroService _mostroService;
  final FlutterSecureStorage _secureStorage;
  final Map<String, MostroMessage> _messages = {};

  final Map<int, StreamSubscription<MostroMessage>> _subscriptions = {};

  MostroRepository(this._mostroService, this._secureStorage);

  MostroMessage? getOrderById(String orderId) => _messages[orderId];
  List<MostroMessage> get allMessages => _messages.values.toList();

  Stream<MostroMessage> _subscribe(Session session) {
    final stream = _mostroService.subscribe(session);
    final subscription = stream.listen(
      (msg) async {
        // TODO: handle other message payloads
        if (msg.payload is Order) {
          _messages[msg.id!] = msg;
          await saveMessage(msg);
        }
      },
      onError: (error) {
        // Log or handle subscription errors
        print('Error in subscription for session ${session.keyIndex}: $error');
      },
      cancelOnError: false,
    );
    _subscriptions[session.keyIndex] = subscription;
    return stream;
  }

  Stream<MostroMessage> resubscribeOrder(String orderId) {
    final session = _mostroService.getSessionByOrderId(orderId);
    return _subscribe(session!);
  }

  Future<Stream<MostroMessage>> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {
    final session =
        await _mostroService.takeSellOrder(orderId, amount, lnAddress);
    return _subscribe(session);
  }

  Future<Stream<MostroMessage>> takeBuyOrder(
      String orderId, int? amount) async {
    final session = await _mostroService.takeBuyOrder(orderId, amount);
    return _subscribe(session);
  }

  Future<void> sendInvoice(String orderId, String invoice) async {
    await _mostroService.sendInvoice(orderId, invoice);
  }

  Future<Stream<MostroMessage>> publishOrder(MostroMessage order) async {
    final session = await _mostroService.publishOrder(order);
    return _subscribe(session);
  }

  Future<void> cancelOrder(String orderId) async {
    await _mostroService.cancelOrder(orderId);
  }

  Future<void> saveMessages() async {
    for (var m in _messages.values.toList()) {
      await _secureStorage.write(
          key: '${SecureStorageKeys.message}-${m.id}',
          value: jsonEncode(m.toJson()));
    }
  }

  Future<void> saveMessage(MostroMessage message) async {
    await _secureStorage.write(
        key: '${SecureStorageKeys.message}-${message.id}',
        value: jsonEncode(message.toJson()));
  }

  Future<void> deleteMessage(String messageId) async {
    _messages.remove(messageId);
    await _secureStorage.delete(key: '${SecureStorageKeys.message}-$messageId');
  }

  Future<void> loadMessages() async {
    final allEntries = await _secureStorage.readAll();
    for (final entry in allEntries.entries) {
      if (entry.key.startsWith(SecureStorageKeys.message.value)) {
        try {
          final msg = MostroMessage.deserialized(entry.value);
          _messages[msg.id!] = msg;
        } catch (e) {
          print('Error deserializing message for key ${entry.key}: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }
}
