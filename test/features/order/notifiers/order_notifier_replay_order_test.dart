import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
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

import '../../../mocks.mocks.dart';

/// `sync()` rebuilds the order state from the persisted history. That history
/// used to be replayed in receive order, so a `waiting-seller-to-pay` written
/// after `hold-invoice-payment-accepted` (relay replay newest-first, or two
/// concurrent decrypts) left the buyer on waiting-payment: no fiat-sent button
/// and no chat, until a dispute moved the state again.
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
          MockSessionStorage(),
          Settings(
            relays: [],
            fullPrivacyMode: false,
            mostroPublicKey: 'test',
          ),
        ) {
    state = [];
  }
}

/// Real `sync()`, no live stream.
class _SyncOnlyOrderNotifier extends OrderNotifier {
  _SyncOnlyOrderNotifier(super.orderId, super.ref);

  @override
  void subscribe() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'test-order-id';

  late Database db;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = await newDatabaseFactoryMemory().openDatabase('replay_order.db');

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

  MostroMessage<Order> message(Action action, Status status,
          {required int eventCreatedAt}) =>
      MostroMessage<Order>(
        action: action,
        id: orderId,
        eventCreatedAt: eventCreatedAt,
        payload: Order(
          id: orderId,
          kind: OrderType.sell,
          status: status,
          fiatCode: 'VES',
          fiatAmount: 100,
          paymentMethod: 'face to face',
        ),
      );

  test('an earlier message written last does not win the replay', () async {
    // Arrange: the newer event was decrypted and persisted first.
    final storage = container.read(mostroStorageProvider);
    await storage.addMessage(
      'newer',
      message(Action.holdInvoicePaymentAccepted, Status.active,
          eventCreatedAt: 2000),
    );
    await storage.addMessage(
      'older',
      message(Action.waitingSellerToPay, Status.waitingPayment,
          eventCreatedAt: 1000),
    );

    // Act
    final notifier = container.read(orderNotifierProvider(orderId).notifier);
    await notifier.sync();

    // Assert
    final state = container.read(orderNotifierProvider(orderId));
    expect(state.status, Status.active);
    expect(state.action, Action.holdInvoicePaymentAccepted);
    expect(state.getActions(Role.buyer), contains(Action.fiatSent));
  });
}
