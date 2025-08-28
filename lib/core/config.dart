import 'package:flutter/foundation.dart';

class Config {
  // Nostr configuration
  static const List<String> nostrRelays = [
    'ws://192.168.1.69:7000',
    //'ws://127.0.0.1:7000',
    //'ws://192.168.1.103:7000',
    //'ws://10.0.2.2:7000', // mobile emulator
  ];

  // Mostro hexkey
  static const String mostroPubKey = 
          '82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390';
  //'9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980';

  static const String dBName = 'mostro.db';
  static const String dBPassword = 'mostro';



  // Timeout for relay connections

  static const Duration nostrConnectionTimeout = Duration(seconds: 30);

  static bool fullPrivacyMode = false;

  // Debug mode
  static bool get isDebug => !kReleaseMode;

  // Mostro version
  static int mostroVersion = 1;

  static const int expirationSeconds = 900;
  static const int expirationHours = 24;
  static const int cleanupIntervalMinutes = 30;
  static const int sessionExpirationHours = 36;
  


  // Notification configuration

  static String notificationChannelId = 'mostro_mobile';
  static int notificationId = 38383;

  // Timeouts for timeout detection (new critical operations)
  static const Duration timeoutDetectionTimeout = Duration(seconds: 8);
  static const Duration messageStorageTimeout = Duration(seconds: 5);
}
