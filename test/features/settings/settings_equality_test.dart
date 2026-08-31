import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// `Settings` is watched at the root `MaterialApp` and by service providers.
/// The relay sync writes it twice per kind 10002 event, so without value
/// equality every sync rebuilt the whole app shell, and the exchange service
/// was recreated — dropping its 1 h rate cache and refetching over relays.
void main() {
  Settings base() => Settings(
        relays: ['wss://relay.a'],
        fullPrivacyMode: false,
        mostroPublicKey: 'pk1',
        blacklistedRelays: ['wss://bad'],
        userRelays: [
          {'url': 'wss://mine', 'source': 'user'},
        ],
      );

  group('Settings value equality', () {
    test('equal field values compare equal, including lists', () {
      final first = base();
      final second = base();

      expect(identical(first.relays, second.relays), isFalse);
      expect(identical(first.blacklistedRelays, second.blacklistedRelays),
          isFalse);
      expect(identical(first.userRelays, second.userRelays), isFalse);
      expect(identical(first.userRelays.single, second.userRelays.single),
          isFalse);
      expect(first, second);
      expect(base().hashCode, base().hashCode);
    });

    test('value-equal replacements do not notify settings listeners', () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final notifier = SettingsNotifier(SharedPreferencesAsync());
      addTearDown(notifier.dispose);
      var notifications = 0;
      notifier.addListener((_) => notifications++, fireImmediately: false);

      await notifier.updateRelays(<String>[]);

      expect(notifications, 0);
    });

    test('copyWith of an unrelated field breaks equality', () {
      expect(base(), isNot(base().copyWith(isLoggingEnabled: true)));
      expect(base(), isNot(base().copyWith(mostroPublicKey: 'pk2')));
      expect(
        base(),
        isNot(base().copyWith(relays: const ['wss://relay.b'])),
      );
    });
  });

  group('exchangeServiceProvider scoping', () {
    test('an unrelated settings change keeps the same service instance',
        () async {
      // Arrange
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(SharedPreferencesAsync()),
      ]);
      addTearDown(container.dispose);
      final before = container.read(exchangeServiceProvider);

      // Act: toggling logging must not touch the exchange service
      await container
          .read(settingsProvider.notifier)
          .updateLoggingEnabled(true);
      await Future<void>.delayed(Duration.zero);

      // Assert
      expect(
        identical(before, container.read(exchangeServiceProvider)),
        isTrue,
        reason: 'recreating the service drops its 1 h rate cache and '
            'refetches every watched currency over the relays',
      );
    });
  });
}
