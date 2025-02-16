import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/features/notifications/notification_controller.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationController.initializeLocalNotifications();
  await NotificationController.initializeIsolateReceivePort();

  final nostrService = NostrService();
  await nostrService.init();
  final biometricsHelper = BiometricsHelper();
  final sharedPreferences = SharedPreferencesAsync();
  final secureStorage = const FlutterSecureStorage();
  final database = await openMostroDatabase();

  runApp(
    ProviderScope(
      overrides: [
        nostrServicerProvider.overrideWithValue(nostrService),
        biometricsHelperProvider.overrideWithValue(biometricsHelper),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(secureStorage),
        mostroDatabaseProvider.overrideWithValue(database),
      ],
      child: const MostroApp(),
    ),
  );
}
