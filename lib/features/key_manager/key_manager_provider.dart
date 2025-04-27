import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/key_manager/key_notifier.dart';
import 'package:mostro_mobile/features/key_manager/key_storage.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final keyManagerProvider = Provider<KeyManager>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final sharedPrefs = ref.watch(sharedPreferencesProvider);

  final keyStorage =
      KeyStorage(secureStorage: secureStorage, sharedPrefs: sharedPrefs);
  final keyDerivator = KeyDerivator("m/44'/1237'/38383'/0");
  return KeyManager(keyStorage, keyDerivator);
});

// Provide the KeyNotifier + current master key
final masterKeyNotifierProvider =
    StateNotifierProvider<KeyNotifier, NostrKeyPairs?>((ref) {
  final manager = ref.watch(keyManagerProvider);
  final settings = ref.watch(settingsProvider);
  return KeyNotifier(manager, settings.copyWith());
});

final tradeKeyNotifierProvider =
    StateNotifierProvider.family<KeyNotifier, NostrKeyPairs?, String>((ref, userSessionId) {
  final manager = ref.watch(keyManagerProvider);
  
  final settings = ref.watch(settingsProvider);
  return KeyNotifier(manager, settings.copyWith());
});
