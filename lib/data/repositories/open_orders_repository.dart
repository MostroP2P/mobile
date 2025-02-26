import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

const orderEventKind = 38383;
const orderFilterDurationHours = 48;

class OpenOrdersRepository implements OrderRepository<NostrEvent> {
  final NostrService _nostrService;
  NostrEvent? _mostroInstance;
  Settings _settings;

  final StreamController<List<NostrEvent>> _eventStreamController =
      StreamController.broadcast();
  final Map<String, NostrEvent> _events = {};
  final _logger = Logger();
  StreamSubscription<NostrEvent>? _subscription;

  NostrEvent? get mostroInstance => _mostroInstance;

  OpenOrdersRepository(this._nostrService, this._settings);

  /// Subscribes to events matching the given filter.
  void subscribeToOrders() {
    _subscription?.cancel();

    final filterTime =
        DateTime.now().subtract(Duration(hours: orderFilterDurationHours));
    var filter = NostrFilter(
      kinds: const [orderEventKind],
      authors: [_settings.mostroPublicKey],
      since: filterTime,
    );

    _subscription = _nostrService.subscribeToEvents(filter).listen((event) {
      if (event.type == 'order') {
        _events[event.orderId!] = event;
        _eventStreamController.add(_events.values.toList());
      } else if (event.type == 'info' && event.pubkey == _settings.mostroPublicKey) {
        _logger.i('Mostro instance info loaded: $event');
        _mostroInstance = event;
      }
    }, onError: (error) {
      _logger.e('Error in order subscription: $error');
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _eventStreamController.close();
    _events.clear();
  }

  @override
  Future<NostrEvent?> getOrderById(String orderId) {
    return Future.value(_events[orderId]);
  }

  Stream<List<NostrEvent>> get eventsStream => _eventStreamController.stream;

  List<NostrEvent> get currentEvents => _events.values.toList();

  @override
  Future<void> addOrder(NostrEvent order) {
    // TODO: implement addOrder
    throw UnimplementedError();
  }

  @override
  Future<void> deleteOrder(String orderId) {
    // TODO: implement deleteOrder
    throw UnimplementedError();
  }

  @override
  Future<List<NostrEvent>> getAllOrders() {
    // TODO: implement getAllOrders
    throw UnimplementedError();
  }

  @override
  Future<void> updateOrder(NostrEvent order) {
    // TODO: implement updateOrder
    throw UnimplementedError();
  }

  void updateSettings(Settings settings) {
    if (_settings.mostroPublicKey != settings.mostroPublicKey) {
      _logger.i('Mostro instance changed, updating...');
      _settings = settings.copyWith();
      _events.clear();
      subscribeToOrders();
    } else {
      _settings = settings.copyWith();
    }
  }
}
