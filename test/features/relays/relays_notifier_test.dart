import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/relays/relay.dart';
import 'package:mostro_mobile/features/relays/relay_url_validator.dart';
import 'package:mostro_mobile/features/relays/relays_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// The notifier's relay sync needs providers that are not under test here;
/// every access fails and is caught by the notifier, which keeps the URL
/// validation path (the subject of these tests) fully usable.
class _FakeRef extends Fake implements Ref {}

/// Runs [body] against a notifier built with the given validator, then
/// disposes it and lets its pending sync/retry timers elapse so the test
/// binding's "timer still pending" invariant holds.
Future<void> withNotifier(
  WidgetTester tester, {
  required bool allowInsecure,
  required Future<void> Function(RelaysNotifier notifier) body,
}) async {
  final notifier = RelaysNotifier(
    SettingsNotifier(SharedPreferencesAsync()),
    _FakeRef(),
    urlValidator: RelayUrlValidator(allowInsecure: allowInsecure),
  );
  try {
    await body(notifier);
  } finally {
    notifier.dispose();
    await tester.pump(const Duration(seconds: 30));
  }
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('RelaysNotifier.normalizeRelayUrl wiring', () {
    testWidgets('rejects ws:// when insecure relays are not allowed (release)',
        (tester) async {
      await withNotifier(tester, allowInsecure: false, body: (notifier) async {
        expect(notifier.normalizeRelayUrl('ws://localhost:7000'), isNull);
        expect(notifier.normalizeRelayUrl('wss://127.0.0.1:7000'), isNull);
      });
    });

    testWidgets('accepts ws://localhost when insecure relays are allowed',
        (tester) async {
      await withNotifier(tester, allowInsecure: true, body: (notifier) async {
        expect(notifier.normalizeRelayUrl('ws://localhost:7000'),
            'ws://localhost:7000');
        expect(notifier.normalizeRelayUrl('ws://relay.example.com'), isNull);
      });
    });
  });

  group('RelaysNotifier.addRelayWithSmartValidation', () {
    const onlySecure = 'only-secure';
    const noHttp = 'no-http';
    const invalidDomain = 'invalid-domain';
    const alreadyExists = 'already-exists';
    const notValid = 'not-valid';

    Future<RelayValidationResult> add(RelaysNotifier n, String input) =>
        n.addRelayWithSmartValidation(
          input,
          errorOnlySecure: onlySecure,
          errorNoHttp: noHttp,
          errorInvalidDomain: invalidDomain,
          errorAlreadyExists: alreadyExists,
          errorNotValid: notValid,
        );

    testWidgets('maps each rejection reason to its own message',
        (tester) async {
      await withNotifier(tester, allowInsecure: true, body: (notifier) async {
        expect(
            (await add(notifier, 'ws://relay.example.com')).error, onlySecure);
        expect((await add(notifier, 'http://localhost:7000')).error, noHttp);
        expect((await add(notifier, 'wss://10.0.256.1')).error, invalidDomain);
        expect((await add(notifier, 'relay')).error, invalidDomain);
      });
    });

    testWidgets('detects duplicates through the canonical key', (tester) async {
      await withNotifier(tester, allowInsecure: false, body: (notifier) async {
        // Stored before trailing-slash/lowercase normalization existed.
        notifier.state = [Relay(url: 'wss://Relay.Example.com/')];

        final result = await add(notifier, 'wss://relay.example.com');

        expect(result.success, isFalse);
        expect(result.error, alreadyExists);
      });
    });
  });

  group('RelaysNotifier blacklist matching', () {
    testWidgets(
        'does not persist relays whose legacy URL differs only in case or '
        'trailing slash from a blacklist entry', (tester) async {
      await withNotifier(tester, allowInsecure: false, body: (notifier) async {
        await notifier.settings.addToBlacklist('wss://blocked.example.com');

        // Legacy state entries stored before normalization existed.
        await notifier.addRelay(Relay(url: 'wss://Blocked.Example.com/'));
        await notifier.addRelay(Relay(url: 'wss://kept.example.com'));

        expect(notifier.settings.state.relays, ['wss://kept.example.com']);
        expect(
            notifier.isRelayBlacklisted('wss://Blocked.Example.com//'), isTrue);
        expect(notifier.isRelayBlacklisted('wss://kept.example.com'), isFalse);
      });
    });
  });
}
