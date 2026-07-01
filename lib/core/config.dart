import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/core/config/communities.dart';

class Config {
  // Nostr configuration
  static const List<String> nostrRelays = [
    'wss://relay.mostro.network',
    //'ws://127.0.0.1:7000',
    //'ws://192.168.1.103:7000',
    //'ws://10.0.2.2:7000', // mobile emulator
  ];

  // Defensive bootstrap relays: connected only to discover a Mostro's kind
  // 10002 relay list at cold start or when no discovered relay is reachable.
  // Not persisted nor shown in the relay list; they idle once relays are found.
  static const List<String> bootstrapRelays = [
    'wss://relay.mostro.network',
    'wss://mostro-p2p.tech',
    'wss://nos.lol',
    'wss://relay.damus.io',
  ];

  // Derived from trustedCommunities to maintain single source of truth
  static final List<Map<String, String>> trustedMostroNodes =
      trustedCommunities
          .map((c) => {
                'pubkey': c.pubkey,
                'name': c.region,
              })
          .toList();

  // Mostro hexkey (backward compatible, overridable via env variable)
  static const String mostroPubKey = String.fromEnvironment(
    'MOSTRO_PUB_KEY',
    defaultValue: defaultMostroPubkey,
  );

  static const String dBName = 'mostro.db';
  static const String dBPassword = 'mostro';

  // Timeout for relay connections (WebSocket handshake per relay)
  static const Duration relayConnectionTimeout = Duration(seconds: 5);

  // Timeout for relay operations (EOSE responses, publish OK)
  static const Duration nostrOperationTimeout = Duration(seconds: 20);

  // Grace period for discovered relays to connect before engaging bootstrap.
  static const Duration relayDiscoveryTimeout = Duration(seconds: 6);

  static bool fullPrivacyMode = false;

  // Debug mode
  static bool get isDebug => !kReleaseMode;

  // Key derivation configuration
  static const String keyDerivationPath = "m/44'/1237'/38383'/0";

  static const int expirationSeconds = 900;
  static const int expirationHours = 24;
  static const int cleanupIntervalMinutes = 30;
  static const int sessionExpirationHours = 720;

  // Notification configuration
  static String notificationChannelId = 'mostro_mobile';
  static int notificationId = 38383;

  // Push notification server configuration
  static const String pushServerUrl = String.fromEnvironment(
    'PUSH_SERVER_URL',
    defaultValue: 'https://mostro-push-server.fly.dev',
  );
  // Logger configuration
  static const int logMaxEntries = 1000;
  static const int logBatchDeleteSize = 100;
}
