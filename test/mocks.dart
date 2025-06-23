import 'package:dart_nostr/dart_nostr.dart';
import 'package:mockito/annotations.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/data/repositories/session_storage.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/features/key_manager/key_manager.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_notifier.dart';
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
  MockSessionNotifier(MockKeyManager super.keyManager,
      MockSessionStorage super.sessionStorage, super.settings);

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

void main() {}
