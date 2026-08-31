import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
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

/// A message that carries nothing new is not a state change.
///
/// The live subscription assigns `state = state.updateWith(msg)` for every
/// message it receives, and relays re-deliver the same gift wrap freely. With
/// identity equality every one of those duplicates fanned out to every watcher
/// of the order — the order book sort, the dispute futures, each trade screen.
/// `AbstractMostroNotifier.updateShouldNotify` compares by value so only real
/// changes are emitted.

class _SilentNostrService extends NostrService {
  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(NostrRequest request) =>
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

/// Keeps the real [subscribe] wiring — the code under test — but never reads
/// storage, so only the delivered messages move the state.
class _StreamOnlyOrderNotifier extends OrderNotifier {
  _StreamOnlyOrderNotifier(super.orderId, super.ref);

  @override
  Future<void> sync() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'test-order-id';

  late Database db;
  late ProviderContainer container;
  late StreamController<MostroMessage?> messages;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    db = await newDatabaseFactoryMemory().openDatabase('no_op_emission.db');
    messages = StreamController<MostroMessage?>.broadcast();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        sessionNotifierProvider
            .overrideWith((ref) => _FixedSessionNotifier(ref)),
        mostroMessageStreamProvider.overrideWith((ref, id) => messages.stream),
        orderNotifierProvider.overrideWith(
          (ref, id) => _StreamOnlyOrderNotifier(id, ref),
        ),
      ],
    );
  });

  tearDown(() async {
    await messages.close();
    container.dispose();
    await db.close();
  });

  MostroMessage<Order> waitingBuyerInvoice({int fiatAmount = 100}) =>
      MostroMessage<Order>(
        action: Action.waitingBuyerInvoice,
        id: orderId,
        payload: Order(
          id: orderId,
          kind: OrderType.sell,
          status: Status.waitingBuyerInvoice,
          fiatCode: 'VES',
          fiatAmount: fiatAmount,
          paymentMethod: 'face to face',
        ),
      );

  Future<void> deliver(MostroMessage message) async {
    messages.add(message);
    await Future<void>.delayed(Duration.zero);
  }

  test('a re-delivered message does not emit a second identical state',
      () async {
    final notifier = container.read(orderNotifierProvider(orderId).notifier);
    notifier.subscribe();

    final emitted = <OrderState>[];
    final removeListener =
        notifier.addListener((state) => emitted.add(state), fireImmediately: false);
    addTearDown(removeListener);

    await deliver(waitingBuyerInvoice());
    expect(emitted, hasLength(1),
        reason: 'precondition: the first message is a real change');

    await deliver(waitingBuyerInvoice());

    expect(emitted, hasLength(1),
        reason: 'the duplicate carries the same values, so no watcher of this '
            'order should be asked to rebuild');
    expect(notifier.state.status, Status.waitingBuyerInvoice);
  });

  test('a message that changes a field still emits', () async {
    final notifier = container.read(orderNotifierProvider(orderId).notifier);
    notifier.subscribe();

    final emitted = <OrderState>[];
    final removeListener =
        notifier.addListener((state) => emitted.add(state), fireImmediately: false);
    addTearDown(removeListener);

    await deliver(waitingBuyerInvoice());
    await deliver(waitingBuyerInvoice(fiatAmount: 200));

    expect(emitted, hasLength(2),
        reason: 'value equality must not swallow a real payload change');
    expect(emitted.last.order?.fiatAmount, 200);
  });
}
