import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

class OpenOrdersRepository implements OrderRepository {
  final NostrService _nostrService;
  final StreamController<List<NostrEvent>> _eventStreamController =
      StreamController.broadcast();
  final Map<String, NostrEvent> _events = {};

  Stream<List<NostrEvent>> get eventsStream => _eventStreamController.stream;

  OpenOrdersRepository(this._nostrService);

  void subscribe(NostrFilter filter) {
    _nostrService.subscribeToEvents(filter).listen((event) {
      final key = '${event.kind}-${event.pubkey}-${event.orderId}';
      _events[key] = event;
      _eventStreamController.add(_events.values.toList());
    });
  }

  void dispose() {
    _eventStreamController.close();
  }
}
