import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/event_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:sembast/sembast_memory.dart';

/// Feeds events into the orders stream MostroService listens on.
class _StubSubscriptionManager implements SubscriptionManager {
  final _orders = StreamController<NostrEvent>.broadcast();

  @override
  Stream<NostrEvent> get orders => _orders.stream;

  void emit(NostrEvent event) => _orders.add(event);

  Future<void> close() => _orders.close();

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves a fixed session list; MostroService only reads the list.
class _StubSessionNotifier extends StateNotifier<List<Session>>
    implements SessionNotifier {
  _StubSessionNotifier(super.sessions);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// Serves fixed settings; MostroService only reads the value.
class _StubSettingsNotifier extends StateNotifier<Settings>
    implements SettingsNotifier {
  _StubSettingsNotifier(super.settings);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

/// A kind-14 Mostro message, signed by [node] and addressed to [recipient].
Future<NostrEvent> _mostroMessage(
  NostrKeyPairs node,
  String recipient, {
  DateTime? createdAt,
}) async {
  final payload = jsonEncode([
    {
      'order': {'version': 2, 'action': 'fiat-sent-ok', 'id': 'order-1'}
    }
  ]);

  return NostrEvent.fromPartialData(
    kind: 14,
    content: await NostrUtils.encryptNIP44(payload, node.private, recipient),
    keyPairs: node,
    createdAt: createdAt,
    tags: [
      ['p', recipient],
    ],
  );
}

/// The genuine event's id and signature lifted onto different content — free
/// for any relay that has seen the original, and caught by the signature check
/// because the id no longer matches what the event says.
NostrEvent _idCollidingForgery(NostrEvent genuine) {
  return NostrEvent(
    id: genuine.id,
    sig: genuine.sig,
    pubkey: genuine.pubkey,
    kind: genuine.kind,
    content: 'not the content this id was signed over',
    createdAt: genuine.createdAt,
    tags: genuine.tags,
  );
}

void main() {
  late Database eventDb;
  late Database mostroDb;
  late NostrKeyPairs nodeKeys;
  late Session session;
  late _StubSubscriptionManager subscriptions;
  late ProviderContainer container;

  setUp(() async {
    eventDb = await newDatabaseFactoryMemory().openDatabase('events');
    mostroDb = await newDatabaseFactoryMemory().openDatabase('mostro');

    nodeKeys = NostrUtils.generateKeyPair();
    session = Session(
      masterKey: NostrUtils.generateKeyPair(),
      tradeKey: NostrUtils.generateKeyPair(),
      keyIndex: 1,
      fullPrivacy: false,
      startTime: DateTime.now(),
      orderId: 'order-1',
    );

    subscriptions = _StubSubscriptionManager();

    container = ProviderContainer(
      overrides: [
        eventDatabaseProvider.overrideWithValue(eventDb),
        mostroDatabaseProvider.overrideWithValue(mostroDb),
        subscriptionManagerProvider.overrideWithValue(subscriptions),
        sessionNotifierProvider.overrideWith(
          (ref) => _StubSessionNotifier([session]),
        ),
        settingsProvider.overrideWith(
          (ref) => _StubSettingsNotifier(
            Settings(
              relays: const ['wss://relay.example'],
              fullPrivacyMode: false,
              mostroPublicKey: nodeKeys.public,
            ),
          ),
        ),
      ],
    );

    container.read(mostroServiceProvider).init();
  });

  tearDown(() async {
    container.dispose();
    await subscriptions.close();
    await eventDb.close();
    await mostroDb.close();
  });

  Future<List<MostroMessage>> storedMessages() =>
      MostroStorage(db: mostroDb).getAllMessages();

  // The dedup store is a censorship surface for as long as it is written
  // before the event is authenticated. A relay that has seen a genuine message
  // can paste its id onto anything; if that claims the slot, the genuine event
  // behind it is dropped as a duplicate and the user never learns of it.
  test('a rejected forgery does not censor the genuine event', () async {
    final genuine = await _mostroMessage(nodeKeys, session.tradeKey.public);
    final eventStore = EventStorage(db: eventDb);

    subscriptions.emit(_idCollidingForgery(genuine));
    await pumpEventQueue();

    expect(
      await eventStore.hasItem(genuine.id!),
      isFalse,
      reason: 'an unauthenticated event must not claim a durable dedup slot',
    );

    subscriptions.emit(genuine);
    await pumpEventQueue();

    expect(await eventStore.hasItem(genuine.id!), isTrue);
    expect(await storedMessages(), hasLength(1));
  });

  test('a genuine event is still deduplicated on re-delivery', () async {
    final genuine = await _mostroMessage(nodeKeys, session.tradeKey.public);

    subscriptions.emit(genuine);
    await pumpEventQueue();
    subscriptions.emit(genuine);
    await pumpEventQueue();

    expect(await storedMessages(), hasLength(1));
  });

  // Two relays delivering the same event land in separate microtasks, and
  // hasItem is async, so both can observe it as unseen. The in-flight claim is
  // what closes that window now that the durable write happens later.
  test('concurrent delivery of the same event is processed once', () async {
    final genuine = await _mostroMessage(nodeKeys, session.tradeKey.public);

    subscriptions.emit(genuine);
    subscriptions.emit(genuine);
    await pumpEventQueue();

    expect(await storedMessages(), hasLength(1));
  });

  test('an event for an unknown trade key is not recorded', () async {
    final stranger = NostrUtils.generateKeyPair();
    final event = await _mostroMessage(nodeKeys, stranger.public);

    subscriptions.emit(event);
    await pumpEventQueue();

    expect(await EventStorage(db: eventDb).hasItem(event.id!), isFalse);
    expect(await storedMessages(), isEmpty);
  });

  // MM-021: freshness has to come from the wire. The kind-14 created_at is
  // covered by the node's signature, so a relay can withhold a message but
  // cannot make an old one look new — which is exactly what a replayed
  // fiat-sent-ok needs in order to re-arm the seller's Release button.
  group('message freshness', () {
    test('the stored timestamp is the node-signed created_at', () async {
      final signedAt = DateTime.now().subtract(const Duration(days: 3));
      final event = await _mostroMessage(
        nodeKeys,
        session.tradeKey.public,
        createdAt: signedAt,
      );

      subscriptions.emit(event);
      await pumpEventQueue();

      final stored = await storedMessages();
      expect(stored, hasLength(1));
      // Tolerance of a second: Nostr serialises created_at in whole seconds,
      // so an event that has crossed the wire loses the sub-second part while
      // one built in-process keeps it.
      expect(
        stored.single.timestamp,
        closeTo(signedAt.millisecondsSinceEpoch, 1000),
      );
    });

    test('a replayed old message does not read as fresh', () async {
      final event = await _mostroMessage(
        nodeKeys,
        session.tradeKey.public,
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      subscriptions.emit(event);
      await pumpEventQueue();

      final stored = await storedMessages();
      final age = DateTime.now().millisecondsSinceEpoch -
          stored.single.timestamp!;
      expect(
        age,
        greaterThan(const Duration(days: 29).inMilliseconds),
        reason: 'receive time would have made this look seconds old',
      );
    });

    test('a fresh message keeps a current timestamp', () async {
      final event = await _mostroMessage(nodeKeys, session.tradeKey.public);

      subscriptions.emit(event);
      await pumpEventQueue();

      final stored = await storedMessages();
      final age = DateTime.now().millisecondsSinceEpoch -
          stored.single.timestamp!;
      expect(age, lessThan(const Duration(minutes: 1).inMilliseconds));
    });
  });
}
