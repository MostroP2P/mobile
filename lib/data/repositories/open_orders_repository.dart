import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

const orderEventKind = 38383;
const infoEventKind = 38385;
const orderFilterDurationHours = 48;

class OpenOrdersRepository implements OrderRepository<NostrEvent> {
  final NostrService _nostrService;
  NostrEvent? _mostroInstance;
  Settings _settings;

  final StreamController<List<NostrEvent>> _eventStreamController =
      StreamController.broadcast();

  /// Emits the connected node's kind-38385 info event whenever it is (re)loaded.
  /// Consumers (e.g. the transport resolver in [SubscriptionManager]) listen to
  /// this to react when the node's `protocol_version` becomes known, since the
  /// info event arrives asynchronously after the initial subscription.
  final StreamController<NostrEvent> _mostroInstanceController =
      StreamController.broadcast();
  final Map<String, NostrEvent> _events = {};
  StreamSubscription<NostrEvent>? _subscription;

  /// The node info subscription, kept apart from the order one. See
  /// [_subscribeToOrders] for why it does not share a filter.
  StreamSubscription<NostrEvent>? _infoSubscription;

  /// Polls for NostrService readiness when the repository is built before
  /// init() completes, so the order subscription can be opened once Nostr is up.
  Timer? _initRetryTimer;

  static const _initRetryInterval = Duration(milliseconds: 200);
  static const _maxInitRetries = 150; // ~30s before giving up

  NostrEvent? get mostroInstance => _mostroInstance;

  Stream<NostrEvent> get mostroInstanceStream =>
      _mostroInstanceController.stream;

  OpenOrdersRepository(this._nostrService, this._settings) {
    // Subscribe to orders and initialize data
    _subscribeToOrders();
    // Immediately emit current (possibly empty) cache so UI doesn't remain in loading state
    _emitEvents();
  }

  /// Subscribes to the node's order book and to its info event.
  ///
  /// The two go out as separate requests, and the info one first. Sharing a
  /// filter put the info event behind the entire order backlog: one request,
  /// answered in whatever order the relay holds its events, and the book is
  /// every order the node touched in [orderFilterDurationHours].
  ///
  /// That ordering is not cosmetic. The fee rate the settlement checks are
  /// anchored to is read off this event, and it is pinned at the moment the
  /// user commits to a trade. A take that lands before the event does pins no
  /// rate at all, and the settlement screens then report — for the life of
  /// that trade — an amount they could not verify. On a slow link, or via a
  /// `mostro:` deep link that opens straight onto the take screen, that is a
  /// caution the user's bandwidth decides rather than the node's honesty.
  ///
  /// Its own request also lets the filter drop `since`. The node republishes
  /// its info event on its own schedule, not the order book's, so a node that
  /// has been quiet for longer than the order window would otherwise never
  /// announce itself at all.
  void _subscribeToOrders() {
    _subscription?.cancel();
    _infoSubscription?.cancel();
    _initRetryTimer?.cancel();

    // The repository can be built before NostrService.init() completes (the
    // provider build races with app initialization). Subscribing while Nostr is
    // uninitialized throws and poisons the cached provider, so defer until it is
    // ready instead.
    if (!_nostrService.isInitialized) {
      logger.i('Nostr not initialized yet; deferring order subscription');
      _scheduleSubscribeWhenReady();
      return;
    }

    final nodePubkey = _settings.mostroPublicKey;

    _infoSubscription = _nostrService
        .subscribeToEvents(
          NostrRequest(
            filters: [
              NostrFilter(
                kinds: [infoEventKind],
                authors: [nodePubkey],
                limit: 1,
              ),
            ],
          ),
        )
        .listen(_handleInfoEvent, onError: (error) {
      logger.e('Error in Mostro info subscription: $error');
    });

    final filterTime =
        DateTime.now().subtract(Duration(hours: orderFilterDurationHours));

    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: [orderEventKind],
          since: filterTime,
          authors: [nodePubkey],
        ),
      ],
    );

    _subscription = _nostrService.subscribeToEvents(request).listen((event) {
      if (event.type == 'order') {
        _events[event.orderId!] = event;
        _eventStreamController.add(_events.values.toList());
      }
    }, onError: (error) {
      logger.e('Error in order subscription: $error');
      // Optionally, you could auto-resubscribe here if desired
    });

    // Ensure listeners receive at least one snapshot right after (re)subscription
    _emitEvents();
  }

  /// Records the node's info event and announces it.
  ///
  /// The author is checked rather than assumed: a node switch cancels this
  /// subscription, but an event already in flight when it does must not be
  /// reported as the new node's terms.
  void _handleInfoEvent(NostrEvent event) {
    if (event.kind != infoEventKind ||
        event.pubkey != _settings.mostroPublicKey) {
      return;
    }

    logger.i('Mostro instance info loaded: $event');
    _mostroInstance = event;
    if (!_mostroInstanceController.isClosed) {
      _mostroInstanceController.add(event);
    }
  }

  /// Polls NostrService until it reports initialized, then opens the order
  /// subscription. Bounded so a failed init does not leave a timer running
  /// forever; `reloadData`/`updateSettings` can still re-trigger later.
  void _scheduleSubscribeWhenReady() {
    var attempts = 0;
    _initRetryTimer = Timer.periodic(_initRetryInterval, (timer) {
      attempts++;
      if (_nostrService.isInitialized) {
        timer.cancel();
        _initRetryTimer = null;
        _subscribeToOrders();
      } else if (attempts >= _maxInitRetries) {
        timer.cancel();
        _initRetryTimer = null;
        logger.w(
          'Nostr still not initialized after waiting; order subscription not started',
        );
      }
    });
  }

  void _emitEvents() {
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(_events.values.toList());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _infoSubscription?.cancel();
    _initRetryTimer?.cancel();
    _eventStreamController.close();
    _mostroInstanceController.close();
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
      logger.i('Mostro instance changed, updating...');
      _settings = settings.copyWith();
      _events.clear();
      // Drop the previous node's info so stale data is not reported for the new
      // instance until its kind 38385 is received again.
      _mostroInstance = null;
      _subscribeToOrders();
    } else {
      _settings = settings.copyWith();
    }
  }

  void reloadData() {
    logger.i('Reloading repository data');
    _subscribeToOrders();
    _emitEvents();
  }

  /// Clear in-memory order cache and reload from relays (used during account restore)
  void clearCache() {
    logger.i('Clearing order cache and reloading');
    _events.clear();
    _subscribeToOrders(); // Resubscribe to reload orders from relays
  }
}
