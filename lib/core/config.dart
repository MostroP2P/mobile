import 'package:flutter/foundation.dart';

class Config {
  // Nostr configuration
  static const List<String> nostrRelays = [
    'wss://relay.mostro.network',
    //'ws://127.0.0.1:7000',
    //'ws://192.168.1.103:7000',
    //'ws://10.0.2.2:7000', // mobile emulator
  ];

  // Trusted Mostro nodes registry
  static const String _defaultMostroPubKey =
      '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';

  static const List<Map<String, String>> trustedMostroNodes = [
    {
      'pubkey': _defaultMostroPubKey,
      'name': 'Mostro P2P',
      'about':
          'A peer-to-peer Bitcoin trading daemon over the Lightning Network',
      'picture': 'https://mostro.network/assets/images/favicon.png',
      'website': 'https://mostro.network/',
    },
  ];

  // Mostro hexkey (backward compatible, overridable via env variable)
  static const String mostroPubKey = String.fromEnvironment(
    'MOSTRO_PUB_KEY',
    defaultValue: _defaultMostroPubKey,
  );

  static const String dBName = 'mostro.db';
  static const String dBPassword = 'mostro';

  // Timeout for relay connections

  static const Duration nostrConnectionTimeout = Duration(seconds: 30);

  static bool fullPrivacyMode = false;

  // Debug mode
  static bool get isDebug => !kReleaseMode;

  // Mostro version
  static int mostroVersion = 1;

  // Key derivation configuration
  static const String keyDerivationPath = "m/44'/1237'/38383'/0";

  static const int expirationSeconds = 900;
  static const int expirationHours = 24;
  static const int cleanupIntervalMinutes = 30;
  static const int sessionExpirationHours = 72;

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
