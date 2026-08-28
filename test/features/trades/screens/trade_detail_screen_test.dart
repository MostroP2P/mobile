import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/automation/automation_ids.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/trades/screens/trade_detail_screen.dart';
import 'package:mostro_mobile/features/trades/widgets/mostro_message_detail_widget.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Nostr that is up but has nothing to say, so the real
/// `orderRepositoryProvider` builds without scheduling its readiness retry
/// timer and the order book cache stays empty — which is the whole point of
/// these tests: no public 38383 event for the order.
class _SilentNostrService extends NostrService {
  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(NostrRequest request) =>
      const Stream.empty();
}

/// Mostro service that skips `init()`: the screen never talks to it, but
/// [OrderNotifier] reads it while constructing.
class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

/// [OrderNotifier] with a fixed state. `sync()` and `subscribe()` are the two
/// hooks its constructor calls, so overriding them keeps the storage and the
/// message stream out of the test.
class _FixedOrderNotifier extends OrderNotifier {
  _FixedOrderNotifier(super.orderId, super.ref, OrderState fixedState) {
    state = fixedState;
  }

  @override
  Future<void> sync() async {}

  @override
  void subscribe() {}
}

/// The maker's own session for the order: a seller session on a sell order
/// is what `_isUserCreator` reads as "you created this".
Session _makerSession() => Session(
      masterKey: NostrKeyPairs(private: '0' * 63 + '1'),
      tradeKey: NostrKeyPairs(private: '0' * 63 + '1'),
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.utc(2026, 1, 1),
      orderId: 'order-1',
      role: Role.seller,
    );

/// The public 38383 the creator reputation card is built from.
NostrEvent _publicOrderEvent() => NostrEvent(
      id: 'event-id',
      kind: 38383,
      content: '',
      sig: 'sig',
      pubkey: 'a' * 64,
      createdAt: DateTime.utc(2026, 1, 1),
      tags: const [
        ['d', 'order-1'],
        ['k', 'sell'],
        ['f', 'CUP'],
        ['s', 'pending'],
        ['amt', '495'],
        ['fa', '333'],
        ['pm', 'Saldo movil'],
        ['premium', '0'],
        ['rating', '{"total_reviews":3,"total_rating":4.5,"days":10}'],
      ],
    );

Order _order(Status status) => Order(
      id: 'order-1',
      kind: OrderType.sell,
      status: status,
      amount: 495,
      fiatCode: 'CUP',
      fiatAmount: 333,
      paymentMethod: 'Saldo móvil',
    );

void main() {
  const orderId = 'order-1';

  late Database db;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // Empty stores are enough: the screen reads no session and no message.
    db = await databaseFactoryMemory.openDatabase('trade_detail_test.db');
  });

  tearDown(() async => db.close());

  Future<void> pumpDetail(
    WidgetTester tester,
    OrderState tradeState, {
    Session? session,
    NostrEvent? publicEvent,
  }) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        sessionProvider(orderId).overrideWith((ref) => session),
        eventProvider(orderId).overrideWithValue(publicEvent),
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        orderNotifierProvider.overrideWith(
          (ref, id) => _FixedOrderNotifier(id, ref, tradeState),
        ),
        mostroMessageHistoryProvider(orderId)
            .overrideWith((ref) => Stream.value(const <MostroMessage>[])),
        // A real one ticks on a Timer and would hang pumpAndSettle.
        countdownTimeProvider.overrideWith(
          (ref) => Stream.value(DateTime.fromMillisecondsSinceEpoch(0)),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
        home: TradeDetailScreen(orderId: orderId),
      ),
    ));
    await tester.pump();
  }

  group('TradeDetailScreen without the public 38383 event', () {
    // Regression: the screen used to require the public event, which the order
    // book only caches for 48h. A settled, canceled or old order left it stuck
    // on a spinner with no app bar and no way out.
    testWidgets('renders a settled order the book no longer caches',
        (tester) async {
      await pumpDetail(
        tester,
        OrderState(
          status: Status.settledHoldInvoice,
          action: actions.Action.released,
          order: _order(Status.settledHoldInvoice),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(orderId), findsOneWidget);
    });

    testWidgets('drops the creator reputation instead of the whole screen',
        (tester) async {
      // Pending order: the only place the public event was ever used.
      await pumpDetail(
        tester,
        OrderState(
          status: Status.pending,
          action: actions.Action.newOrder,
          order: _order(Status.pending),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text(orderId), findsOneWidget);
    });

    testWidgets('still waits while the trade state has no order', (tester) async {
      await pumpDetail(
        tester,
        OrderState(
          status: Status.pending,
          action: actions.Action.newOrder,
          order: null,
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('order.status on the trade detail', () {
    // Regression: on the maker's own pending order the screen swaps the
    // Mostro message card — the only widget carrying `order.status` — for the
    // creator reputation, so the status vanished from the whole pending phase
    // of every order this app creates. See docs/automation-contract.md.
    testWidgets('is exposed on a pending order you created', (tester) async {
      await pumpDetail(
        tester,
        OrderState(
          status: Status.pending,
          action: actions.Action.newOrder,
          order: _order(Status.pending),
        ),
        session: _makerSession(),
        publicEvent: _publicOrderEvent(),
      );

      // The branch under test: reputation shown, message card gone.
      expect(find.byType(MostroMessageDetail), findsNothing);

      final status = find.bySemanticsIdentifier(AutomationIds.orderStatus);
      expect(status, findsOneWidget);
      expect(
        tester.getSemantics(status).getSemanticsData().label,
        Status.pending.value,
      );
    });

    testWidgets('is exposed once on the message card branch', (tester) async {
      // The other branch still owns the identifier, and the two never both
      // render: a driver always finds exactly one node.
      await pumpDetail(
        tester,
        OrderState(
          status: Status.waitingPayment,
          action: actions.Action.payInvoice,
          order: _order(Status.waitingPayment),
        ),
        session: _makerSession(),
        publicEvent: _publicOrderEvent(),
      );

      expect(find.byType(MostroMessageDetail), findsOneWidget);

      final status = find.bySemanticsIdentifier(AutomationIds.orderStatus);
      expect(status, findsOneWidget);
      expect(
        tester.getSemantics(status).getSemanticsData().label,
        Status.waitingPayment.value,
      );
    });
  });
}
