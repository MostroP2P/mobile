import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/notifiers/abstract_mostro_notifier.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Drives the real `subscribe()` path and records what reaches `handleEvent`.
class _Probe extends AbstractMostroNotifier {
  _Probe(super.orderId, super.ref);

  final List<bool> userInitiatedFlags = [];

  void setApplied(int? timestamp) => lastAppliedTimestamp = timestamp;

  void markCancel() => AbstractMostroNotifier.markUserInitiatedCancel(orderId);

  @override
  Future<void> handleEvent(
    MostroMessage event, {
    bool bypassTimestampGate = false,
    Status? previousStatus,
    bool wasUserInitiatedCancel = false,
  }) async {
    userInitiatedFlags.add(wasUserInitiatedCancel);
  }
}

class _FakePrefs implements SharedPreferencesAsync {
  final Map<String, String> strings = {};

  @override
  Future<String?> getString(String key) async => strings[key];

  @override
  Future<void> setString(String key, String value) async {
    strings[key] = value;
  }

  @override
  Future<void> remove(String key) async => strings.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

class _StubSessionNotifier extends StateNotifier<List<Session>>
    implements SessionNotifier {
  _StubSessionNotifier() : super(const []);

  @override
  Session? getSessionByOrderId(String orderId) => null;

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}

void main() {
  const orderId = 'order-1';

  late ProviderContainer container;
  late Provider<_Probe> probeProvider;
  late StreamController<MostroMessage?> messages;

  // Real wall-clock dates: subscribe() gates handleEvent on the message being
  // within the last 60 seconds, so a fixed test date would never get through.
  final nowMs = DateTime.now().millisecondsSinceEpoch;
  final hourAgoMs =
      DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch;
  final weekAgoMs =
      DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;

  setUp(() {
    messages = StreamController<MostroMessage?>.broadcast();
    probeProvider = Provider<_Probe>((ref) => _Probe(orderId, ref));
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(_FakePrefs()),
        sessionNotifierProvider.overrideWith((ref) => _StubSessionNotifier()),
        mostroMessageStreamProvider.overrideWith((ref, id) => messages.stream),
      ],
    );
    AbstractMostroNotifier.unmarkUserInitiatedCancel(orderId);
  });

  tearDown(() {
    AbstractMostroNotifier.unmarkUserInitiatedCancel(orderId);
    messages.close();
    container.dispose();
  });

  MostroMessage cancel(int timestamp) => MostroMessage(
        action: Action.canceled,
        id: orderId,
        timestamp: timestamp,
      );

  /// Lets the stream deliver and the unawaited handleEvent settle.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  // The marker is set by cancelOrder and consumed once, to tell a voluntary
  // cancel apart from a counterparty inactivity timeout — both arrive as
  // Action.canceled. A replayed cancel that spends it leaves the genuine
  // response to be read as a timeout: wrong notification, and a bonded order's
  // session deletion deferred instead of immediate.
  group('a stale canceled does not consume the user-initiated marker', () {
    test('the genuine response that follows is still user-initiated',
        () async {
      final probe = container.read(probeProvider)
        ..setApplied(hourAgoMs)
        ..markCancel();
      probe.subscribe();

      messages.add(cancel(weekAgoMs));
      await settle();

      // Refused outright: nothing reached handleEvent.
      expect(probe.userInitiatedFlags, isEmpty);

      messages.add(cancel(nowMs));
      await settle();

      expect(probe.userInitiatedFlags, [true]);
    });

    test('with no replay in front of it the marker still works', () async {
      final probe = container.read(probeProvider)
        ..setApplied(hourAgoMs)
        ..markCancel();
      probe.subscribe();

      messages.add(cancel(nowMs));
      await settle();

      expect(probe.userInitiatedFlags, [true]);
    });

    test('an unmarked cancel is reported as not user-initiated', () async {
      final probe = container.read(probeProvider)..setApplied(hourAgoMs);
      probe.subscribe();

      messages.add(cancel(nowMs));
      await settle();

      expect(probe.userInitiatedFlags, [false]);
    });
  });
}
