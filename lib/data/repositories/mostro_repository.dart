import 'dart:async';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroRepository implements OrderRepository {
  final MostroService _mostroService;
  final FlutterSecureStorage _flutterSecureStorage;
  final Map<String, MostroMessage> _messages = {};

  final Map<int, StreamSubscription<MostroMessage>> _subscriptions = {};

  MostroRepository(this._mostroService, this._flutterSecureStorage);

  MostroMessage? getOrderById(String orderId) => _messages[orderId];

  Stream<MostroMessage> _subscribe(Session session) {
    final stream = _mostroService.subscribe(session);
    final subscription = stream.listen((m) async {
      _messages[m.requestId!] = m;
      await saveMessage(m);
    });
    _subscriptions[session.keyIndex] = subscription;
    return stream;
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
      await _flutterSecureStorage.write(
          key: '${SecureStorageKeys.message}-${m.requestId}',
          value: jsonEncode(m.toJson()));
    }
  }

  Future<void> saveMessage(MostroMessage message) async {
    await _flutterSecureStorage.write(
        key: '${SecureStorageKeys.message}-${message.requestId}',
        value: jsonEncode(message.toJson()));
  }

  Future<void> deleteMessage(String messageId) async {
    await _flutterSecureStorage.delete(
        key: '${SecureStorageKeys.message}-$messageId');
  }

  Future<void> loadMessages() async {
    final allKeys = await _flutterSecureStorage.readAll();
    for (var e in allKeys.entries) {
      if (e.key.startsWith(SecureStorageKeys.message.value)) {
        final message = MostroMessage.deserialized(e.value);
        _messages[message.requestId!] = message;
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
