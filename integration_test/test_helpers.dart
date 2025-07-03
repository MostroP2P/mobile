import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/providers/exchange_service_provider.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/background/abstract_background_service.dart';
import 'package:mostro_mobile/core/app.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as mostro_action;
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/notifiers/navigation_notifier.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/navigation_notifier_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeSharedPreferencesAsync implements SharedPreferencesAsync {
  final Map<String, Object?> _store = {};
  @override
  Future<String?> getString(String key) async => _store[key] as String?;
  @override
  Future<bool> setString(String key, String value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<int?> getInt(String key) async => _store[key] as int?;
  @override
  Future<bool> setInt(String key, int value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<void> clear({Set<String>? allowList}) async {
    _store.clear();
  }

  @override
  Future<bool> containsKey(String key) async {
    return _store.containsKey(key);
  }

  @override
  Future<bool?> getBool(String key) async {
    return _store[key] as bool?;
  }

  @override
  Future<double?> getDouble(String key) async {
    return _store[key] as double?;
  }

  @override
  Future<Set<String>> getKeys({Set<String>? allowList}) async {
    return _store.keys.toSet();
  }

  @override
  Future<List<String>?> getStringList(String key) async {
    return _store[key] as List<String>?;
  }

  @override
  Future<bool> remove(String key) async {
    _store.remove(key);
    return true;
  }

  @override
  Future<bool> setBool(String key, bool value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setDouble(String key, double value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<bool> setStringList(String key, List<String> value) async {
    _store[key] = value;
    return true;
  }

  @override
  Future<Map<String, Object?>> getAll({Set<String>? allowList}) async {
    return Map.fromEntries(_store.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!)));
  }
}

class FakeSecureStorage implements FlutterSecureStorage {
  final Map<String, String?> _store = {};
  @override
  Future<void> deleteAll(
      {AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions,
      WebOptions? webOptions}) async {
    _store.clear();
  }

  @override
  Future<String?> read(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions,
      WebOptions? webOptions}) async {
    return _store[key];
  }

  @override
  Future<void> write(
      {required String key,
      required String? value,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions,
      WebOptions? webOptions}) async {
    _store[key] = value;
  }

  // Unused methods
  @override
  Future<void> delete(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions,
      WebOptions? webOptions}) async {
    _store.remove(key);
  }

  @override
  Future<Map<String, String>> readAll(
      {AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions,
      WebOptions? webOptions}) async {
    return Map.fromEntries(_store.entries
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!)));
  }

  @override
  // TODO: implement aOptions
  AndroidOptions get aOptions => throw UnimplementedError();

  @override
  Future<bool> containsKey(
      {required String key,
      AppleOptions? iOptions,
      AndroidOptions? aOptions,
      LinuxOptions? lOptions,
      WebOptions? webOptions,
      AppleOptions? mOptions,
      WindowsOptions? wOptions}) {
    // TODO: implement containsKey
    throw UnimplementedError();
  }

  @override
  // TODO: implement iOptions
  IOSOptions get iOptions => throw UnimplementedError();

  @override
  Future<bool?> isCupertinoProtectedDataAvailable() {
    // TODO: implement isCupertinoProtectedDataAvailable
    throw UnimplementedError();
  }

  @override
  // TODO: implement lOptions
  LinuxOptions get lOptions => throw UnimplementedError();

  @override
  // TODO: implement mOptions
  AppleOptions get mOptions => throw UnimplementedError();

  @override
  // TODO: implement onCupertinoProtectedDataAvailabilityChanged
  Stream<bool>? get onCupertinoProtectedDataAvailabilityChanged =>
      throw UnimplementedError();

  @override
  void registerListener(
      {required String key, required ValueChanged<String?> listener}) {
    // TODO: implement registerListener
  }

  @override
  void unregisterAllListeners() {
    // TODO: implement unregisterAllListeners
  }

  @override
  void unregisterAllListenersForKey({required String key}) {
    // TODO: implement unregisterAllListenersForKey
  }

  @override
  void unregisterListener(
      {required String key, required ValueChanged<String?> listener}) {
    // TODO: implement unregisterListener
  }

  @override
  // TODO: implement wOptions
  WindowsOptions get wOptions => throw UnimplementedError();

  @override
  // TODO: implement webOptions
  WebOptions get webOptions => throw UnimplementedError();
}

class FakeBackgroundService implements BackgroundService {
  @override
  Future<void> init() async {}
  @override
  void subscribe(List<NostrFilter> filters) {}
  @override
  void updateSettings(settings) {}
  @override
  Future<void> setForegroundStatus(bool isForeground) async {}
  @override
  Future<bool> unsubscribe(String subscriptionId) async => true;
  @override
  Future<void> unsubscribeAll() async {}
  @override
  Future<int> getActiveSubscriptionCount() async => 0;
  @override
  bool get isRunning => false;
}

class FakeMostroService implements MostroService {
  FakeMostroService(this.ref);
  @override
  final Ref ref;

  @override
  void init({List<NostrKeyPairs>? keys}) {}

  @override
  Future<void> submitOrder(MostroMessage order) async {
    final storage = ref.read(mostroStorageProvider);
    final orderMsg = MostroMessage<Order>(
      action: mostro_action.Action.newOrder,
      id: 'order_${order.requestId}',
      requestId: order.requestId,
      payload: order.payload as Order,
    );
    await storage.addMessage('msg_${order.requestId}', orderMsg);
  }

  @override
  Future<void> takeBuyOrder(String orderId, int? amount) async {}

  @override
  Future<void> takeSellOrder(
      String orderId, int? amount, String? lnAddress) async {}

  @override
  Future<void> sendInvoice(String orderId, String invoice, int? amount) async {}

  @override
  Future<void> cancelOrder(String orderId) async {}

  @override
  Future<void> sendFiatSent(String orderId) async {}

  @override
  Future<void> releaseOrder(String orderId) async {}

  @override
  Future<void> disputeOrder(String orderId) async {}

  @override
  Future<void> submitRating(String orderId, int rating) async {}

  @override
  Future<Session> publishOrder(MostroMessage order) =>
      throw UnimplementedError();

  @override
  void updateSettings(Settings settings) {}
    
  @override
  void dispose() {
    // TODO: implement dispose
  }
}

Future<void> pumpTestApp(WidgetTester tester) async {
  final prefs = FakeSharedPreferencesAsync();
  final secure = FakeSecureStorage();
  final db = await databaseFactoryMemory.openDatabase('mostro.db');
  final eventsDb = await databaseFactoryMemory.openDatabase('events.db');
  final storage = MostroStorage(db: db);
  final settingsNotifier = SettingsNotifier(prefs);
  await settingsNotifier.init();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith((ref) => settingsNotifier),
        currencyCodesProvider.overrideWith((ref) async => {
              'VES': Currency(
                symbol: 'Bs',
                name: 'Venezuelan Bolívar',
                symbolNative: 'Bs',
                code: 'VES',
                emoji: '🇻🇪',
                decimalDigits: 2,
                namePlural: 'Venezuelan bolívars',
                price: false,
              ),
              'USD': Currency(
                symbol: '\$',
                name: 'US Dollar',
                symbolNative: '\$',
                code: 'USD',
                emoji: '🇺🇸',
                decimalDigits: 2,
                namePlural: 'US dollars',
                price: false,
              ),
            }),
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(secure),
        mostroDatabaseProvider.overrideWithValue(db),
        eventDatabaseProvider.overrideWithValue(eventsDb),
        mostroStorageProvider.overrideWithValue(storage),
        backgroundServiceProvider.overrideWithValue(FakeBackgroundService()),
        mostroServiceProvider.overrideWith((ref) => FakeMostroService(ref)),
        navigationProvider.overrideWith((ref) => NavigationNotifier()),
        appInitializerProvider.overrideWith((ref) => Future.value()),
      ],
      child: const MostroApp(),
    ),
  );
  await tester.pumpAndSettle();
}
