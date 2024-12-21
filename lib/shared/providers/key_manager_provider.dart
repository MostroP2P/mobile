import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/key_manager.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

final keyManagerProvider = Provider<KeyManager>((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  final sharedPrefs = ref.watch(sharedPreferencesProvider);
  return KeyManager(secureStorage: secureStorage, sharedPreferences: sharedPrefs);
});