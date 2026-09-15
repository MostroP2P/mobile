import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Sessions play no part in these scenarios; this keeps the harness free of
/// the generated mocks.
class _NoopSessionStorage implements SessionStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

/// Retaking an order reuses its notifier, so the replay has to tell the first
/// message of the *new* take from a late copy of the old one. Getting that
/// wrong either leaves the previous cycle's invoice on the bond screen (#731)
/// or lets a duplicate reopen a terminal trade (#723). Both directions are
/// exercised here against the real `sync()`.
class _SilentNostrService extends NostrService {
  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(
    NostrRequest request, {
    void Function(String)? onEose,
  }) =>
      const Stream.empty();
}

class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

class _FixedSessionNotifier extends SessionNotifier {
  _FixedSessionNotifier(Ref ref)
      : super(
          ref,
          _NoopSessionStorage(),
          Settings(
            relays: [],
            fullPrivacyMode: false,
            mostroPublicKey: 'test',
          ),
        ) {
    state = [];
  }
}

/// Real `sync()`, no live stream — and no unawaited pass either.
///
/// The OrderNotifier constructor starts a `sync()` nothing can await, and a
/// second `sync()` while that one runs only sets `_resyncRequested` and
/// returns. Swallowing the constructor's call leaves the pass the test awaits
/// as the only one, so the assertions never race hydration.
class _SyncOnlyOrderNotifier extends OrderNotifier {
  _SyncOnlyOrderNotifier(super.orderId, super.ref);

  bool _constructorSyncSkipped = false;

  @override
  void subscribe() {}

  @override
  Future<void> sync() async {
    if (!_constructorSyncSkipped) {
      _constructorSyncSkipped = true;
      return;
    }
    return super.sync();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'test-order-id';

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = await newDatabaseFactoryMemory().openDatabase('retake_cycle.db');

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        sessionNotifierProvider
            .overrideWith((ref) => _FixedSessionNotifier(ref)),
        orderNotifierProvider.overrideWith(
          (ref, id) => _SyncOnlyOrderNotifier(id, ref),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Order orderPayload(Status status) => Order(
        id: orderId,
        kind: OrderType.buy,
        status: status,
        amount: 16558,
        fiatCode: 'EUR',
        fiatAmount: 10,
        paymentMethod: 'face to face',
      );

  MostroMessage<Order> message(
    Action action,
    Status status, {
    required int eventCreatedAt,
    required int timestamp,
  }) =>
      MostroMessage<Order>(
        action: action,
        id: orderId,
        eventCreatedAt: eventCreatedAt,
        timestamp: timestamp,
        payload: orderPayload(status),
      );

  MostroMessage<PaymentRequest> invoice(
    Action action,
    String bolt11, {
    required int eventCreatedAt,
    required int timestamp,
  }) =>
      MostroMessage<PaymentRequest>(
        action: action,
        id: orderId,
        eventCreatedAt: eventCreatedAt,
        timestamp: timestamp,
        payload: PaymentRequest(
          order: orderPayload(Status.pending),
          lnInvoice: bolt11,
        ),
      );

  Future<void> persist(List<(String, MostroMessage)> history) async {
    final storage = container.read(mostroStorageProvider);
    for (final (key, msg) in history) {
      await storage.addMessage(key, msg);
    }
  }

  Future<OrderStateSnapshot> syncedState() async {
    // _SyncOnlyOrderNotifier swallows the constructor's unawaited sync(), so
    // this is the only pass and awaiting it is enough.
    await container.read(orderNotifierProvider(orderId).notifier).sync();
    final state = container.read(orderNotifierProvider(orderId));
    return OrderStateSnapshot(
      status: state.status,
      action: state.action,
      invoice: state.paymentRequest?.lnInvoice,
      fiatWasSent: state.fiatWasSent,
    );
  }

  group('a genuine retake', () {
    test('ends on the new bond invoice, never the cancelled escrow one',
        () async {
      await persist([
        ('a', invoice(Action.payBondInvoice, 'lnbcbond',
            eventCreatedAt: 1000, timestamp: 1)),
        ('b', invoice(Action.payInvoice, 'lnbcescrow',
            eventCreatedAt: 2000, timestamp: 2)),
        (
          'c',
          message(Action.waitingBuyerInvoice, Status.waitingBuyerInvoice,
              eventCreatedAt: 2500, timestamp: 3)
        ),
        (
          'd',
          message(Action.canceled, Status.canceled,
              eventCreatedAt: 3000, timestamp: 4)
        ),
        ('e', invoice(Action.payBondInvoice, 'lnbcbond2',
            eventCreatedAt: 4000, timestamp: 5)),
      ]);

      final state = await syncedState();

      expect(state.status, Status.waitingTakerBond);
      expect(state.action, Action.payBondInvoice);
      expect(state.invoice, 'lnbcbond2');
    });

    test('a history that ends on the cancel keeps no invoice at all', () async {
      await persist([
        ('a', invoice(Action.payBondInvoice, 'lnbcbond',
            eventCreatedAt: 1000, timestamp: 1)),
        ('b', invoice(Action.payInvoice, 'lnbcescrow',
            eventCreatedAt: 2000, timestamp: 2)),
        (
          'c',
          message(Action.canceled, Status.canceled,
              eventCreatedAt: 3000, timestamp: 3)
        ),
      ]);

      final state = await syncedState();

      expect(state.status, Status.canceled);
      expect(state.invoice, isNull);
    });
  });

  group('late copies must not reopen a terminal order', () {
    // `created_at` has one-second resolution and relays replay newest-first,
    // so a duplicate from the same second as the cancel sorts after it.
    test('same-second copy of a setup message after canceled', () async {
      await persist([
        (
          'a',
          message(Action.waitingSellerToPay, Status.waitingPayment,
              eventCreatedAt: 1000, timestamp: 1)
        ),
        (
          'b',
          message(Action.holdInvoicePaymentAccepted, Status.active,
              eventCreatedAt: 2000, timestamp: 2)
        ),
        (
          'c',
          message(Action.canceled, Status.canceled,
              eventCreatedAt: 3000, timestamp: 3)
        ),
        (
          'd',
          message(Action.waitingSellerToPay, Status.waitingPayment,
              eventCreatedAt: 3000, timestamp: 4)
        ),
      ]);

      expect((await syncedState()).status, Status.canceled);
    });

    test('same-second copy of a mid-trade message after canceled', () async {
      await persist([
        (
          'a',
          message(Action.waitingSellerToPay, Status.waitingPayment,
              eventCreatedAt: 1000, timestamp: 1)
        ),
        (
          'b',
          message(Action.holdInvoicePaymentAccepted, Status.active,
              eventCreatedAt: 2000, timestamp: 2)
        ),
        (
          'c',
          message(Action.canceled, Status.canceled,
              eventCreatedAt: 3000, timestamp: 3)
        ),
        (
          'd',
          message(Action.holdInvoicePaymentAccepted, Status.active,
              eventCreatedAt: 3000, timestamp: 4)
        ),
      ]);

      expect((await syncedState()).status, Status.canceled);
    });

    // `canceled-by-admin` and `expired` take the same path: they are just
    // more statuses `endsTradeCycle` covers. They are not driven from here
    // because an `admin-*` message is itself dropped without a tracked
    // dispute (`rejectsAdminDisputeMessage`), which would prove nothing
    // about the cycle rule.
  });

  group('live delivery is not ordered', () {
    test('a cancel from the previous cycle cannot void the new invoice',
        () async {
      await persist([
        ('a', invoice(Action.payBondInvoice, 'lnbcbond',
            eventCreatedAt: 1000, timestamp: 1)),
        (
          'b',
          message(Action.canceled, Status.canceled,
              eventCreatedAt: 3000, timestamp: 2)
        ),
        ('c', invoice(Action.payBondInvoice, 'lnbcbond2',
            eventCreatedAt: 4000, timestamp: 3)),
      ]);

      // Replay leaves the notifier inside the new cycle…
      expect((await syncedState()).invoice, 'lnbcbond2');

      // …and the previous cycle's cancel, delivered late by the live stream,
      // must not reach the state: it would void the invoice on screen, and
      // downstream it deletes the session and navigates away.
      final notifier =
          container.read(orderNotifierProvider(orderId).notifier);
      final lateCancel = message(Action.canceled, Status.canceled,
          eventCreatedAt: 3000, timestamp: 9);

      expect(notifier.precedesActiveCycle(lateCancel), isTrue);
      final after =
          notifier.applyToCycle(container.read(orderNotifierProvider(orderId)),
              lateCancel);

      expect(after.status, Status.waitingTakerBond);
      expect(after.paymentRequest?.lnInvoice, 'lnbcbond2');
    });
  });

  group('a pending cooperative cancel is not a cycle end', () {
    test('a late setup copy keeps fiatWasSent', () async {
      await persist([
        (
          'a',
          message(Action.buyerTookOrder, Status.active,
              eventCreatedAt: 1000, timestamp: 1)
        ),
        (
          'b',
          message(Action.fiatSentOk, Status.fiatSent,
              eventCreatedAt: 2000, timestamp: 2)
        ),
        (
          'c',
          message(Action.cooperativeCancelInitiatedByPeer, Status.active,
              eventCreatedAt: 3000, timestamp: 3)
        ),
        (
          'd',
          message(Action.buyerTookOrder, Status.active,
              eventCreatedAt: 3000, timestamp: 4)
        ),
      ]);

      final state = await syncedState();

      expect(state.status, Status.cooperativelyCanceled);
      expect(state.fiatWasSent, isTrue);
    });
  });
}

/// The few fields these scenarios assert on.
class OrderStateSnapshot {
  final Status status;
  final Action action;
  final String? invoice;
  final bool fiatWasSent;

  OrderStateSnapshot({
    required this.status,
    required this.action,
    required this.invoice,
    required this.fiatWasSent,
  });
}
