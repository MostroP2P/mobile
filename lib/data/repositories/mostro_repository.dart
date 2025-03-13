import 'dart:async';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/mostro_service.dart';

class MostroRepository implements OrderRepository<MostroMessage> {
  final MostroService _mostroService;
  final MostroStorage _messageStorage;
  final Map<String, MostroMessage> _messages = {};

  final Map<int, StreamSubscription<MostroMessage>> _subscriptions = {};

  MostroRepository(this._mostroService, this._messageStorage);

  final _logger = Logger();

  @override
  Future<MostroMessage?> getOrderById(String orderId) =>
      Future.value(_messages[orderId]);

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
        _logger
            .e('Error in subscription for session ${session.keyIndex}: $error');
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

  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {
    await _mostroService.sendInvoice(orderId, invoice, amount);
  }

  Future<Stream<MostroMessage>> publishOrder(MostroMessage order) async {
    final session = await _mostroService.publishOrder(order);
    return _subscribe(session);
  }

  Future<void> cancelOrder(String orderId) async {
    await _mostroService.cancelOrder(orderId);
  }

  Future<void> saveMessages() async {
    //for (var m in _messages.values.toList()) {
    //await _messageStorage.addOrder(m);
    //}
  }

  Future<void> saveMessage(MostroMessage message) async {
    //await _messageStorage.addOrder(message);
  }

  Future<void> deleteMessage(String messageId) async {
    _messages.remove(messageId);
    //await _messageStorage.deleteOrder(messageId);
  }

  Future<void> loadMessages() async {
    final allEntries = await _messageStorage.getAllOrders();
    for (final entry in allEntries) {
      _messages[entry.id!] = entry;
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  Future<void> addOrder(MostroMessage order) {
    // TODO: implement addOrder
    throw UnimplementedError();
  }

  @override
  Future<void> deleteOrder(String orderId) async {
    _messages.remove(orderId);
    _messageStorage.deleteOrder(orderId);
  }

  @override
  Future<List<MostroMessage>> getAllOrders() {
    // TODO: implement getAllOrders
    throw UnimplementedError();
  }

  @override
  Future<void> updateOrder(MostroMessage order) {
    // TODO: implement updateOrder
    throw UnimplementedError();
  }

  Future<void> sendFiatSent(String orderId) async {
    await _mostroService.sendFiatSent(orderId);
  }

  Future<void> releaseOrder(String orderId) async {
    await _mostroService.releaseOrder(orderId);
  }
}
