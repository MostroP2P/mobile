import 'package:flutter/foundation.dart';

class Config {
  // Configuración de Nostr
  static const List<String> nostrRelays = [
    //'ws://127.0.0.1:7000', // localhost
    //'ws://10.0.2.2:7000', // mobile emulator
    'wss://relay.mostro.network',
  ];

  // hexkey de Mostro
  static const String mostroPubKey =
      '9d9d0455a96871f2dc4289b8312429db2e925f167b37c77bf7b28014be235980';

  // Tiempo de espera para conexiones a relays
  static const Duration nostrConnectionTimeout = Duration(seconds: 30);

  // Modo de depuración
  static bool get isDebug => !kReleaseMode;

  // Versión de Mostro
  static int mostroVersion = 1;
}
