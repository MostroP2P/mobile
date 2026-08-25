import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/trades/screens/trade_detail_screen.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
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

  Future<void> pumpDetail(WidgetTester tester, OrderState tradeState) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
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
}
