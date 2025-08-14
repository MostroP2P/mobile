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
import 'package:mostro_mobile/features/relays/relays_notifier.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_type.dart';
import 'package:mostro_mobile/features/subscriptions/subscription.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/notifiers/session_notifier.dart';
import 'package:sembast/sembast.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'mocks.mocks.dart';

@GenerateMocks([
  NostrService,
  MostroService,
  OpenOrdersRepository,
  SharedPreferencesAsync,
  Database,
  SessionStorage,
  KeyManager,
  MostroStorage,
  Settings,
  Ref,
  ProviderSubscription,
  RelaysNotifier,
])

// Custom mock for SettingsNotifier that returns a specific Settings object
class MockSettingsNotifier extends SettingsNotifier {
  MockSettingsNotifier() : super(MockSharedPreferencesAsync()) {
    state = Settings(
      relays: [],
      fullPrivacyMode: false,
      mostroPublicKey: 'test',
      defaultFiatCode: 'USD',
      selectedLanguage: null,
    );
  }
}

// Custom mock for SessionNotifier that avoids database dependencies
class MockSessionNotifier extends SessionNotifier {
  Session? _mockSession;
  List<Session> _mockSessions = [];
  
  MockSessionNotifier(super.ref, MockKeyManager keyManager,
      MockSessionStorage super.sessionStorage, MockSettings super.settings);

  // Allow tests to set mock return values
  void setMockSession(Session? session) {
    _mockSession = session;
  }
  
  void setMockSessions(List<Session> sessions) {
    _mockSessions = sessions;
  }

  @override
  Session? getSessionByOrderId(String orderId) => _mockSession;

  @override
  List<Session> get sessions => _mockSessions;

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

class MockSubscriptionManager extends SubscriptionManager {
  final StreamController<NostrEvent> _ordersController =
      StreamController<NostrEvent>.broadcast();
  final StreamController<NostrEvent> _chatController =
      StreamController<NostrEvent>.broadcast();
  final Map<SubscriptionType, Subscription> _subscriptions = {};
  NostrFilter? _lastFilter;

  MockSubscriptionManager(super.ref);

  NostrFilter? get lastFilter => _lastFilter;

  @override
  Stream<NostrEvent> get orders => _ordersController.stream;

  @override
  Stream<NostrEvent> get chat => _chatController.stream;

  @override
  Stream<NostrEvent> subscribe({
    required SubscriptionType type,
    required NostrFilter filter,
  }) {
    _lastFilter = filter;

    final request = NostrRequest(filters: [filter]);

    final subscription = Subscription(
      request: request,
      streamSubscription: (type == SubscriptionType.orders
              ? _ordersController.stream
              : _chatController.stream)
          .listen((_) {}),
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
