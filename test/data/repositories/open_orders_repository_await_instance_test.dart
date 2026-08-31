import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

import '../../mocks.mocks.dart';

/// Regression tests for [OpenOrdersRepository.awaitMostroInstance].
///
/// Send paths take the outbound transport from the node's kind-38385 info
/// event. Sending before it arrives means guessing, and a wrong guess is
/// unrecoverable: the node ignores the envelope it does not speak and nothing
/// retries the action. These pin the three outcomes callers depend on.
void main() {
  const mostroPubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  late MockNostrService nostrService;
  late StreamController<NostrEvent> eventController;
  late OpenOrdersRepository repository;

  final settings = Settings(
    relays: const [],
    fullPrivacyMode: false,
    mostroPublicKey: mostroPubkey,
    defaultFiatCode: 'USD',
    selectedLanguage: 'en',
  );

  NostrEvent infoEvent() => NostrEvent(
        id: 'info-1',
        kind: infoEventKind,
        pubkey: mostroPubkey,
        content: '',
        sig: '',
        createdAt: DateTime.now(),
        tags: const [
          ['d', mostroPubkey],
          ['z', 'info'],
          ['protocol_version', '2'],
        ],
      );

  setUp(() {
    nostrService = MockNostrService();
    eventController = StreamController<NostrEvent>.broadcast();
    when(nostrService.isInitialized).thenReturn(true);
    when(nostrService.subscribeToEvents(any))
        .thenAnswer((_) => eventController.stream);
    repository = OpenOrdersRepository(nostrService, settings);
  });

  tearDown(() {
    repository.dispose();
    eventController.close();
  });

  test('returns the cached info event without waiting', () async {
    eventController.add(infoEvent());
    await Future<void>.delayed(Duration.zero);

    final resolved = await repository
        .awaitMostroInstance(timeout: const Duration(seconds: 30));

    expect(resolved, isNotNull);
    expect(resolved!.protocolVersion, 2);
  });

  test('resolves once the info event arrives', () async {
    final pending = repository.awaitMostroInstance(
      timeout: const Duration(seconds: 5),
    );

    await Future<void>.delayed(Duration.zero);
    eventController.add(infoEvent());

    final resolved = await pending;
    expect(resolved, isNotNull);
    expect(resolved!.protocolVersion, 2);
  });

  test('returns null on timeout instead of blocking the send', () async {
    final resolved = await repository.awaitMostroInstance(
      timeout: const Duration(milliseconds: 50),
    );

    expect(resolved, isNull);
  });
}
