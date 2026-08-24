import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/features/order/notifiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../../mocks.mocks.dart';

/// The replay budget bounds a contiguous chain of history reads, not the
/// notifier's lifetime.
///
/// A rejected admin resolution asks for a replay because the dispute it
/// belongs to may not be loaded yet. If the counter were never reset, a
/// startup chain that exhausted it would leave every later rejection unable to
/// replay — and the resolution that triggered it has already been dropped by
/// the stream handler, so it would sit persisted but never applied.

/// Nostr that is up but delivers nothing.
class _SilentNostrService extends NostrService {
  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(NostrRequest request) =>
      const Stream.empty();
}

/// Mostro service that skips `init()`; read by [OrderNotifier]'s constructor.
class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

/// Session notifier pinned to an empty list; never touches storage.
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

/// [OrderNotifier] with the storage read stubbed out, so the test drives the
/// budget bookkeeping rather than sembast.
class _StubbedSyncOrderNotifier extends OrderNotifier {
  _StubbedSyncOrderNotifier(super.orderId, super.ref);

  int syncCalls = 0;

  @override
  Future<void> sync() async {
    syncCalls++;
  }

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
    db = await newDatabaseFactoryMemory().openDatabase('replay_budget.db');

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(_SilentNostrService()),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        sessionNotifierProvider.overrideWith((ref) => _FixedSessionNotifier(ref)),
        orderNotifierProvider.overrideWith(
          (ref, id) => _StubbedSyncOrderNotifier(id, ref),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  _StubbedSyncOrderNotifier buildNotifier() =>
      container.read(orderNotifierProvider(orderId).notifier)
          as _StubbedSyncOrderNotifier;

  group('replay budget across recovery generations', () {
    test('a rejection outside a running pass restores the budget', () {
      final notifier = buildNotifier();

      // Stand in for a startup chain that spent the whole budget.
      notifier.resyncAttempts = 3;
      final callsBefore = notifier.syncCalls;

      notifier.onAdminResolutionRejected(
        MostroMessage(id: orderId, action: Action.adminSettled),
      );

      expect(notifier.resyncAttempts, equals(0),
          reason: 'an exhausted counter must not outlive the chain that spent '
              'it, or every later resolution is stranded');
      expect(notifier.syncCalls, equals(callsBefore + 1),
          reason: 'the rejection must still ask for a replay');
    });

    test('repeated rejections each start with a full budget', () {
      final notifier = buildNotifier();

      for (var i = 0; i < 3; i++) {
        notifier.resyncAttempts = 3;
        notifier.onAdminResolutionRejected(
          MostroMessage(id: orderId, action: Action.adminCanceled),
        );
        expect(notifier.resyncAttempts, equals(0));
      }
    });

    test('the budget starts at zero', () {
      expect(buildNotifier().resyncAttempts, equals(0));
    });
  });
}
