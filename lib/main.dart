import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/background/background_service.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/shared/utils/notification_permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mostro_mobile/features/logs/logs_service.dart'; // 🔹

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa LogsService
  final logsService = LogsService();
  await logsService.init();

  // Captura errores globales y print()
  FlutterError.onError = (details) {
    debugPrint('FlutterError: ${details.exceptionAsString()}\n${details.stack}');
  };

  runZonedGuarded(() async {
    await _startApp(logsService);
  }, (error, stackTrace) {
    debugPrint('ERROR: $error\n$stackTrace'); // LogsService ya lo captura
  });
}

Future<void> _startApp(LogsService logsService) async {
  await requestNotificationPermissionIfNeeded();

  final biometricsHelper = BiometricsHelper();
  final sharedPreferences = SharedPreferencesAsync();
  final secureStorage = const FlutterSecureStorage();

  final mostroDatabase = await openMostroDatabase('mostro.db');
  final eventsDatabase = await openMostroDatabase('events.db');

  final settings = SettingsNotifier(sharedPreferences);
  await settings.init();

  await initializeNotifications();
  _initializeTimeAgoLocalization();

  final backgroundService = createBackgroundService(settings.settings);
  await backgroundService.init();

  final container = ProviderContainer(
    overrides: [
      settingsProvider.overrideWith((ref) => settings),
      backgroundServiceProvider.overrideWithValue(backgroundService),
      biometricsHelperProvider.overrideWithValue(biometricsHelper),
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      secureStorageProvider.overrideWithValue(secureStorage),
      mostroDatabaseProvider.overrideWithValue(mostroDatabase),
      eventDatabaseProvider.overrideWithValue(eventsDatabase),
      logsProvider.overrideWith((ref) => logsService), // 🔹 corrección
    ],
  );

  _initializeRelaySynchronization(container);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MostroApp(),
    ),
  );
}

void _initializeRelaySynchronization(ProviderContainer container) {
  try {
    container.read(relaysProvider);
  } catch (e) {
    debugPrint('Failed to initialize relay synchronization: $e');
  }
}

void _initializeTimeAgoLocalization() {
  timeago.setLocaleMessages('es', timeago.EsMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
}