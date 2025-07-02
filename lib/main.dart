import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/background/background_service.dart';
import 'package:mostro_mobile/background/workmanager.dart';
import 'package:mostro_mobile/notifications/notification_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/shared/utils/notification_permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeWorkManager();

  if (Platform.isAndroid && !Platform.environment.containsKey('FLUTTER_TEST')) {
    await requestNotificationPermissionIfNeeded();
  }

  final biometricsHelper = BiometricsHelper();
  final sharedPreferences = SharedPreferencesAsync();
  final secureStorage = const FlutterSecureStorage();

  final mostroDatabase = await openMostroDatabase('mostro.db');
  final eventsDatabase = await openMostroDatabase('events.db');

  final settings = SettingsNotifier(sharedPreferences);
  await settings.init();

  await initializeNotifications();

  final backgroundService = createBackgroundService(settings.settings);
  await backgroundService.init();

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((b) => settings),
        backgroundServiceProvider.overrideWithValue(backgroundService),
        biometricsHelperProvider.overrideWithValue(biometricsHelper),
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        secureStorageProvider.overrideWithValue(secureStorage),
        mostroDatabaseProvider.overrideWithValue(mostroDatabase),
        eventDatabaseProvider.overrideWithValue(eventsDatabase),
      ],
      child: const MostroApp(),
    ),
  );
}
