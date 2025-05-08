import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
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

  OpenOrdersRepository(this._nostrService, this._settings) {
    // Subscribe to orders and initialize data
    _subscribeToOrders();
    // Immediately emit current (possibly empty) cache so UI doesn't remain in loading state
    _emitEvents();
  }

  /// Subscribes to events matching the given filter.
  void _subscribeToOrders() {
    _subscription?.cancel();

    final filterTime =
        DateTime.now().subtract(Duration(hours: orderFilterDurationHours));

    final filter = NostrFilter(
      kinds: [orderEventKind],
      since: filterTime,
      authors: [_settings.mostroPublicKey],
    );

    final request = NostrRequest(
      filters: [filter],
    );

    _subscription = _nostrService.subscribeToEvents(request).listen((event) {
      if (event.type == 'order') {
        _events[event.orderId!] = event;
        _eventStreamController.add(_events.values.toList());
      } else if (event.type == 'info' &&
          event.pubkey == _settings.mostroPublicKey) {
        _logger.i('Mostro instance info loaded: $event');
        _mostroInstance = event;
      }
    }, onError: (error) {
      _logger.e('Error in order subscription: $error');
      // Optionally, you could auto-resubscribe here if desired
    });

    // Ensure listeners receive at least one snapshot right after (re)subscription
    _emitEvents();
  }

  void _emitEvents() {
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(_events.values.toList());
    }
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

  // Stream that immediately emits current cache to every new listener before
  // forwarding live updates.
  Stream<List<NostrEvent>> get eventsStream async* {
    // Emit cached events synchronously.
    yield _events.values.toList();
    // Forward subsequent updates.
    yield* _eventStreamController.stream;
  }

  @override
  Future<void> addOrder(NostrEvent order) {
    _events[order.id!] = order;
    _emitEvents();
    return Future.value();
  }

  @override
  Future<void> deleteOrder(String orderId) {
    _events.remove(orderId);
    _emitEvents();
    return Future.value();
  }

  @override
  Future<List<NostrEvent>> getAllOrders() {
    return Future.value(_events.values.toList());
  }

  @override
  Future<void> updateOrder(NostrEvent order) {
    if (order.id != null && _events.containsKey(order.id)) {
      _events[order.id!] = order;
      _emitEvents();
    }
    return Future.value();
  }

  void updateSettings(Settings settings) {
    if (_settings.mostroPublicKey != settings.mostroPublicKey) {
      _logger.i('Mostro instance changed, updating...');
      _settings = settings.copyWith();
      _events.clear();
      _subscribeToOrders();
    } else {
      _settings = settings.copyWith();
    }
  }

  void reloadData() {
    _logger.i('Reloading repository data');
    _subscribeToOrders();
    _emitEvents();
  }
}
