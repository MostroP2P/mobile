import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/dispute.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/features/order/models/order_state.dart';
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
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../../mocks.mocks.dart';

/// Nostr service whose subscription is driven by the test.
class _ControlledNostrService extends NostrService {
  final StreamController<NostrEvent> controller =
      StreamController<NostrEvent>.broadcast();

  @override
  bool get isInitialized => true;

  @override
  Stream<NostrEvent> subscribeToEvents(NostrRequest request) {
    // Only the dispute chat subscription is driven by the test; anything else
    // (the open orders repository, for one) must not see these envelopes.
    final wantsChat =
        request.filters.any((f) => f.kinds?.contains(14) ?? false);
    return wantsChat ? controller.stream : const Stream.empty();
  }
}

class _IdleMostroService extends MostroService {
  _IdleMostroService(super.ref);
}

class _FixedOrderNotifier extends OrderNotifier {
  _FixedOrderNotifier(super.orderId, super.ref, OrderState fixedState) {
    state = fixedState;
  }

  @override
  Future<void> sync() async {}

  @override
  void subscribe() {}
}

class _FixedSessionNotifier extends SessionNotifier {
  _FixedSessionNotifier(Ref ref, List<Session> sessions)
      : super(
          ref,
          MockSessionStorage(),
          Settings(
            relays: [],
            fullPrivacyMode: false,
            mostroPublicKey: 'test',
          ),
        ) {
    state = sessions;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const orderId = 'order-1';
  const disputeId = 'dispute-1';

  final tradeKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000001',
  );
  final adminKey = NostrKeyPairs(
    private:
        '0000000000000000000000000000000000000000000000000000000000000003',
  );

  late Session session;
  late Database db;
  late ProviderContainer container;
  late _ControlledNostrService nostrService;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();

    session = Session(
      masterKey: tradeKey,
      tradeKey: tradeKey,
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: orderId,
    )..setAdminPeer(adminKey.public);

    db = await newDatabaseFactoryMemory()
        .openDatabase('dispute_duplicate_envelope.db');
    nostrService = _ControlledNostrService();

    final orderState = OrderState(
      status: Status.dispute,
      action: actions.Action.disputeInitiatedByYou,
      order: null,
      dispute: Dispute(disputeId: disputeId, orderId: orderId),
    );

    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
        mostroDatabaseProvider.overrideWithValue(db),
        nostrServiceProvider.overrideWithValue(nostrService),
        mostroServiceProvider.overrideWith((ref) => _IdleMostroService(ref)),
        eventStorageProvider.overrideWithValue(EventStorage(db: db)),
        sessionNotifierProvider
            .overrideWith((ref) => _FixedSessionNotifier(ref, [session])),
        orderNotifierProvider.overrideWith(
          (ref, id) => _FixedOrderNotifier(id, ref, orderState),
        ),
      ],
    );
  });

  tearDown(() async {
    await nostrService.controller.close();
    container.dispose();
    await db.close();
  });

  test(
      'a valid envelope is still processed when a forged copy with the same '
      'id is being verified', () async {
    final notifier =
        container.read(disputeChatNotifierProvider(disputeId).notifier);
    await pumpEventQueue(times: 100);

    final chatKeys = ChatKeys.fromSharedKey(session.adminSharedKey!);
    final rumor = NostrEventExtensions.createChatRumor(
      senderKeys: adminKey,
      content: 'admin says hi',
    );
    final real = await rumor.chatWrap(chatKeys);

    // The signature is not part of the event id, so a hostile relay can reuse
    // a valid envelope's id on an unverifiable copy. It wins the race here.
    final forged = NostrEvent.deserialized('["EVENT","",${jsonEncode({
          'id': real.id,
          'pubkey': chatKeys.sign.public,
          'created_at': real.createdAt!.millisecondsSinceEpoch ~/ 1000,
          'kind': 14,
          'tags': <List<String>>[],
          'content': 'undecryptable garbage',
          'sig': '0' * 128,
        })}]');

    nostrService.controller.add(forged);
    nostrService.controller.add(real);
    // chatUnwrap verifies and decrypts on a worker isolate, whose spawn takes
    // real wall-clock time: draining the event queue alone can return before
    // the valid envelope has been accepted. Poll until it lands instead.
    await _waitFor(
      () => container.read(disputeChatNotifierProvider(disputeId)).messages
          .isNotEmpty,
    );

    final messages =
        container.read(disputeChatNotifierProvider(disputeId)).messages;
    expect(messages, hasLength(1),
        reason: 'the forgery must not suppress the real message that arrives '
            'while the forged copy is still being verified');
    expect(messages.single.content, 'admin says hi');
    expect(notifier.mounted, isTrue);
  });
}

/// Polls [condition] until it holds or [timeout] elapses, yielding to the
/// event loop between attempts so isolate results can be delivered.
Future<void> _waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}
