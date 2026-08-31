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

/// How long a send path waits for the node's kind-38385 info event before
/// falling back to defaults. The info event normally arrives with the initial
/// order subscription; this only bounds a cold start against a slow relay and
/// stays well under the 10s orphan-session cleanup timer.
const mostroInstanceWaitTimeout = Duration(seconds: 3);

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

  /// Coalesces stream emissions: during a 48 h replay burst every relay copy
  /// used to trigger a full-list emission (and downstream sort/filter).
  static const Duration emitDebounce = Duration(milliseconds: 50);
  Timer? _emitTimer;

  static const _initRetryInterval = Duration(milliseconds: 200);
  static const _maxInitRetries = 150; // ~30s before giving up

  NostrEvent? get mostroInstance => _mostroInstance;

  Stream<NostrEvent> get mostroInstanceStream =>
      _mostroInstanceController.stream;

  /// Returns the node's kind-38385 info event, waiting up to [timeout] for it
  /// if it has not arrived yet.
  ///
  /// The info event carries both the PoW difficulty and the `protocol_version`
  /// that selects the outbound transport, so a send issued before it lands
  /// would have to guess both. Guessing the transport wrong is unrecoverable:
  /// the node ignores the envelope it does not speak and nothing retries the
  /// action. Send paths await this instead; a timeout still falls back to the
  /// caller's defaults (PoW 0, [resolveTransport]'s v2 default) so an
  /// unreachable node degrades rather than blocks the UI.
  Future<NostrEvent?> awaitMostroInstance({
    Duration timeout = mostroInstanceWaitTimeout,
  }) async {
    final cached = _mostroInstance;
    if (cached != null) return cached;
    if (_mostroInstanceController.isClosed) return null;
    try {
      return await _mostroInstanceController.stream.first.timeout(timeout);
    } on TimeoutException {
      logger.w(
        'Mostro instance info did not arrive within '
        '${timeout.inSeconds}s; proceeding with defaults',
      );
      return null;
    } catch (e) {
      logger.w('Failed while waiting for Mostro instance info: $e');
      return null;
    }
  }

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

    final filter = NostrFilter(
      kinds: [orderEventKind, infoEventKind],
      since: filterTime,
      authors: [_settings.mostroPublicKey],
    );

    final request = NostrRequest(
      filters: [filter],
    );

    _subscription = _nostrService.subscribeToEvents(request).listen((event) {
      if (event.type == 'order') {
        final orderId = event.orderId!;
        // Drop duplicate/stale relay copies: kind 38383 is addressable, only
        // the surviving replacement per order id matters.
        final known = _events[orderId];
        if (known != null && !_supersedes(event, known)) {
          return;
        }
        _events[orderId] = event;
        _scheduleEmit();
      } else if (event.kind == infoEventKind &&
          event.pubkey == _settings.mostroPublicKey) {
        // Kind 38385 is addressable too, and it carries pow, protocolVersion
        // and the order limits: a stale relay copy must not roll those back.
        final knownInstance = _mostroInstance;
        if (knownInstance != null && !_supersedes(event, knownInstance)) {
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

  /// NIP-01 retention rule for addressable events: the newest `created_at`
  /// wins and, when two copies share the same second, the lexicographically
  /// lower event id does. Relays apply the same rule, so the copy kept here is
  /// the one that actually survives on the relay set rather than whichever
  /// relay happened to answer first.
  static bool _supersedes(NostrEvent candidate, NostrEvent known) {
    final knownAt = known.createdAt;
    if (knownAt == null) return true;
    final candidateAt = candidate.createdAt;
    if (candidateAt == null) return false;
    // compareTo compares the instant only, so a UTC and a local copy of the
    // same second still tie instead of ordering arbitrarily.
    final byTime = candidateAt.compareTo(knownAt);
    if (byTime != 0) return byTime > 0;
    final candidateId = candidate.id;
    final knownId = known.id;
    if (candidateId == null || knownId == null) return false;
    return candidateId.compareTo(knownId) < 0;
  }

  void _emitEvents() {
    _emitTimer?.cancel();
    _emitTimer = null;
    if (!_eventStreamController.isClosed) {
      _eventStreamController.add(_events.values.toList());
    }
  }

  /// Emits once per [emitDebounce] window instead of once per event.
  void _scheduleEmit() {
    _emitTimer ??= Timer(emitDebounce, _emitEvents);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _initRetryTimer?.cancel();
    _emitTimer?.cancel();
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
