import 'dart:async';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';

class MostroRepository implements OrderRepository {

 // final NostrService _nostrService;

  final StreamController<List<MostroMessage>> _eventStreamController =
      StreamController.broadcast();

  final Map<String, MostroMessage> _orders = {};
  //final SecureStorageManager _secureStorageManager;

  MostroRepository();

  void subscribe(NostrFilter filter) {
    //_nostrService.subscribeToEvents(filter).listen((event) async {

     // final recipient = event.recipient;

     // final session = await _secureStorageManager.loadSession(recipient!);

    //  final form = await decryptMessage(
    //      event.content!, session!.privateKey, event.pubkey);

      //final message = MostroMessage.deserialized(form);
      //_orders[message.requestId!] = message;
      //_eventStreamController.add(_orders.values.toList());
    //});
  }

  MostroMessage? getOrder(String orderId) {
    return _orders[orderId];
  }


}
