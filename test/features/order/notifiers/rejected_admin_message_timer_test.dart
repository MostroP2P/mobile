import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
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

/// A message the guard drops is not a response from Mostro.
///
/// Taking an order arms a 10-second cleanup that deletes the session if Mostro
/// never answers. A forged `admin-*` that the dispute-evidence guard rejects
/// must not disarm it: the take would then have neither a response nor its
/// orphan-session protection.

/// Hands the test the container's [Ref], which the static timer API needs.
final _refProvider = Provider<Ref>((ref) => ref);

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

/// [OrderNotifier] that keeps the real [subscribe] wiring — the code under
/// test — but neither reads storage nor replays on rejection.
class _StreamOnlyOrderNotifier extends OrderNotifier {
  _StreamOnlyOrderNotifier(super.orderId, super.ref);

  @override
  Future<void> sync() async {}

  @override
  void onAdminResolutionRejected(MostroMessage message) {}
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
    db = await newDatabaseFactoryMemory().openDatabase('rejected_timer.db');
    messages = StreamController<MostroMessage?>.broadcast();

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        sessionNotifierProvider
            .overrideWith((ref) => _FixedSessionNotifier(ref)),
        mostroMessageStreamProvider
            .overrideWith((ref, id) => messages.stream),
        orderNotifierProvider.overrideWith(
          (ref, id) => _StreamOnlyOrderNotifier(id, ref),
        ),
      ],
    );
  });

  tearDown(() async {
    AbstractMostroNotifier.cancelSessionTimeoutCleanup(orderId);
    await messages.close();
    container.dispose();
    await db.close();
  });

  /// Feeds [message] through the notifier's live subscription and lets the
  /// listener run.
  Future<void> deliver(MostroMessage message) async {
    messages.add(message);
    await Future<void>.delayed(Duration.zero);
  }

  test('a rejected admin resolution leaves the take timeout armed', () async {
    final notifier =
        container.read(orderNotifierProvider(orderId).notifier);
    notifier.subscribe();

    // The order is live with no dispute anywhere: the guard will reject.
    AbstractMostroNotifier.startSessionTimeoutCleanup(
        orderId, container.read(_refProvider));
    expect(AbstractMostroNotifier.hasSessionTimeoutCleanup(orderId), isTrue,
        reason: 'precondition: the take armed the cleanup');

    await deliver(MostroMessage(id: orderId, action: Action.adminCanceled));

    expect(AbstractMostroNotifier.hasSessionTimeoutCleanup(orderId), isTrue,
        reason: 'a message the guard drops is not a response from Mostro, so '
            'it must not disarm the orphan-session cleanup');
    expect(notifier.state.status, isNot(equals(Status.canceledByAdmin)),
        reason: 'and it must not move the order either');
  });
}
