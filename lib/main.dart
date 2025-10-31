import 'dart:async';
import 'dart:ui'; // 🔹 Agregar para PlatformDispatcher
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/features/relays/relays_provider.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/background/background_service.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/providers.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:mostro_mobile/shared/utils/notification_permission_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mostro_mobile/features/logs/logs_service.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart'; // 🔹 AGREGAR ESTE IMPORT
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart'; // 🔹 AGREGAR

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa LogsService
  final logsService = LogsService();
  await logsService.init();

  // Log de inicio
  logsService.log('🚀 App iniciada');

  // Captura errores globales de Flutter
  FlutterError.onError = (details) {
    logsService.log('❌ FlutterError: ${details.exceptionAsString()}');
    if (details.stack != null) {
      logsService.log('Stack: ${details.stack}');
    }
  };

  // Captura errores de Dart no manejados
  PlatformDispatcher.instance.onError = (error, stack) {
    logsService.log('❌ Uncaught error: $error');
    logsService.log('Stack: $stack');
    return true; // Marca el error como manejado
  };

  runZonedGuarded(
        () async => await _startApp(logsService),
        (error, stackTrace) {
      logsService.log('⚠️ Zone error: $error');
      logsService.log('StackTrace: $stackTrace');
    },
  );
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

  await initializeNotifications(); // 🔹 DESCOMENTADO
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
      logsServiceProvider.overrideWithValue(logsService),
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
    final logsService = container.read(logsServiceProvider);
    logsService.log('Failed to initialize relay synchronization: $e');
  }
}

void _initializeTimeAgoLocalization() {
  timeago.setLocaleMessages('es', timeago.EsMessages());
  timeago.setLocaleMessages('it', timeago.ItMessages());
}