import 'dart:async';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/repositories/order_repository_interface.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

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

  /// Subscribes to events matching the given filter.
  void _subscribeToOrders() {
    _subscription?.cancel();
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

    final filterTime =
        DateTime.now().subtract(Duration(hours: orderFilterDurationHours));

    // Two filters, not one. The order history is deliberately bounded to a
    // recent window, but the info event must not inherit that bound: kind
    // 38385 is addressable, so the node publishes it once at startup and the
    // relay keeps only that copy. A node that has been up longer than the
    // window has an info event older than `since`, and a combined filter would
    // make the relay withhold it — leaving `protocol_version` unknown for the
    // whole session. That used to be harmless because unknown meant v1; now
    // that unknown resolves to v2 it would strand the client on kind 14
    // against a node that only listens on kind 1059.
    final request = NostrRequest(
      filters: [
        NostrFilter(
          kinds: [orderEventKind],
          since: filterTime,
          authors: [_settings.mostroPublicKey],
        ),
        NostrFilter(
          kinds: [infoEventKind],
          authors: [_settings.mostroPublicKey],
          limit: 1,
        ),
      ],
    );

    _subscription = _nostrService.subscribeToEvents(request).listen((event) {
      if (event.type == 'order') {
        _events[event.orderId!] = event;
        _eventStreamController.add(_events.values.toList());
      } else if (event.kind == infoEventKind &&
          event.pubkey == _settings.mostroPublicKey) {
        // The author field alone proves nothing: any relay can hand us an
        // event that merely *claims* the node's pubkey. The info event
        // configures the wire transport (`protocol_version`), the bond policy
        // and the PoW target, so an unsigned forgery is a downgrade primitive.
        if (!NostrUtils.isValidEventSignature(event)) {
          logger.w(
            'Rejecting kind-$infoEventKind info event claiming to be from '
            '${event.pubkey}: signature verification failed',
          );
          return;
        }
        // A valid signature says the node authored this event, not that it
        // still reflects the node's configuration. Relays pick which events
        // they serve and in what order, so without a replacement rule the last
        // one to arrive wins — letting a relay replay a genuinely signed but
        // superseded info event to roll the advertised config back (most
        // importantly `protocol_version` 2 -> 1).
        //
        // Reset to null on instance switch (see updateSettings), so this never
        // blocks the newly selected node's own info event.
        if (!_supersedesCurrentInfo(event)) {
          logger.d(
            'Ignoring kind-$infoEventKind info event ${event.id} from '
            '${event.pubkey} dated ${event.createdAt}: does not supersede '
            '${_mostroInstance?.id} dated ${_mostroInstance?.createdAt}',
          );
          return;
        }
        logger.i('Mostro instance info loaded: $event');
        _mostroInstance = event;
        if (!_mostroInstanceController.isClosed) {
          _mostroInstanceController.add(event);
        }
      }
    }, onError: (error) {
      logger.e('Error in order subscription: $error');
      // Optionally, you could auto-resubscribe here if desired
    });

    // Ensure listeners receive at least one snapshot right after (re)subscription
    _emitEvents();
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

  /// Whether [candidate] replaces the info event currently in use, under
  /// NIP-01's ordering for addressable events: the higher `created_at` wins,
  /// and a tie goes to the lower id.
  ///
  /// The tie-break is what makes this converge. Two events sharing a second
  /// are both genuinely the node's — they cleared the signature check — but
  /// only one of them is the copy every other client will settle on, and a
  /// pure "strictly newer" rule silently keeps whichever the fastest relay
  /// happened to deliver. An exact re-delivery compares equal on both fields
  /// and is still rejected, so this does not reopen the replay window the
  /// check exists to close.
  bool _supersedesCurrentInfo(NostrEvent candidate) {
    final current = _mostroInstance;
    if (current == null) return true;

    final candidateAt = candidate.createdAt;
    if (candidateAt == null) return false;
    final currentAt = current.createdAt;
    if (currentAt == null) return true;

    if (candidateAt.isAfter(currentAt)) return true;
    if (currentAt.isAfter(candidateAt)) return false;

    final candidateId = candidate.id;
    final currentId = current.id;
    if (candidateId == null || currentId == null) return false;
    return candidateId.compareTo(currentId) < 0;
  }

  void _emitEvents() {
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(_events.values.toList());
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
