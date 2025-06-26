import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/features/subscriptions/subscription.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks.mocks.dart';

@GenerateMocks([
  MostroService,
  OpenOrdersRepository,
  SharedPreferencesAsync,
  Database,
  SessionStorage,
  KeyManager,
  MostroStorage,
  Settings,
  Ref,
  SubscriptionManager,
])

// Custom mock for SettingsNotifier that returns a specific Settings object
class MockSettingsNotifier extends SettingsNotifier {
  final Settings _testSettings;

  MockSettingsNotifier(this._testSettings, MockSharedPreferencesAsync prefs)
      : super(prefs) {
    state = _testSettings;
  }
}

// Custom mock for SessionNotifier that avoids database dependencies
class MockSessionNotifier extends SessionNotifier {
  MockSessionNotifier(super.ref, MockKeyManager keyManager,
      MockSessionStorage super.sessionStorage, MockSettings super.settings);

  @override
  Session? getSessionByOrderId(String orderId) => null;

  @override
  List<Session> get sessions => [];

  @override
  Future<Session> newSession(
      {String? orderId, int? requestId, Role? role}) async {
    final mockSession = Session(
      // Dummy private keys for testing purposes only
      masterKey: NostrKeyPairs(
          private:
              '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef'),
      tradeKey: NostrKeyPairs(
          private:
              'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890'),
      keyIndex: 0,
      fullPrivacy: false,
      startTime: DateTime.now(),
    );
    mockSession.orderId = orderId;
    mockSession.role = role;
    return mockSession;
  }
}

// Custom mock for SubscriptionManager
class MockSubscriptionManager extends SubscriptionManager {
  final StreamController<NostrEvent> _ordersController = StreamController<NostrEvent>.broadcast();
  final StreamController<NostrEvent> _chatController = StreamController<NostrEvent>.broadcast();
  final Map<SubscriptionType, Subscription> _subscriptions = {};
  NostrFilter? _lastFilter;
  
  MockSubscriptionManager() : super(MockRef());
  
  NostrFilter? get lastFilter => _lastFilter;
  
  @override
  Stream<NostrEvent> get orders => _ordersController.stream;
  
  @override
  Stream<NostrEvent> get chat => _chatController.stream;
  
  @override
  Stream<NostrEvent> subscribe({
    required SubscriptionType type,
    required NostrFilter filter,
    String? id,
  }) {
    _lastFilter = filter;
    
    final request = NostrRequest(filters: [filter]);
    request.subscriptionId = id ?? type.toString();
    
    final subscription = Subscription(
      request: request,
      streamSubscription: _ordersController.stream.listen((_) {}),
      onCancel: () {},
    );
    
    _subscriptions[type] = subscription;
    
    return type == SubscriptionType.orders ? orders : chat;
  }
  
  @override
  void unsubscribeByType(SubscriptionType type) {
    _subscriptions.remove(type);
  }
  
  @override
  void unsubscribeAll() {
    _subscriptions.clear();
  }
  
  @override
  List<NostrFilter> getActiveFilters(SubscriptionType type) {
    final subscription = _subscriptions[type];
    if (subscription != null && subscription.request.filters.isNotEmpty) {
      return [subscription.request.filters.first];
    }
    return [];
  }
  
  @override
  bool hasActiveSubscription(SubscriptionType type) {
    return _subscriptions.containsKey(type);
  }
  
  // Helper to add events to the stream
  void addEvent(NostrEvent event, SubscriptionType type) {
    if (type == SubscriptionType.orders) {
      _ordersController.add(event);
    } else if (type == SubscriptionType.chat) {
      _chatController.add(event);
    }
  }
  
  @override
  void dispose() {
    _ordersController.close();
    _chatController.close();
    super.dispose();
  }
}

void main() {}
