// lib/core/config.dart

import 'package:flutter/foundation.dart';

class Config {
  // Configuración de Nostr
  static const List<String> nostrRelays = [
    'ws://10.0.2.2:7000',
    'wss://relay.damus.io',
    // Agrega más relays aquí si es necesario
  ];

  // Npub de Mostro
  static const String mostroPubKey =
      'npub1n5yrh6lkvc0l3lcmcfwake4r3ex7jrm0e6lumsc22d8ylf7jwk0qack9tql;';

  // Tiempo de espera para conexiones a relays
  static const Duration nostrConnectionTimeout = Duration(seconds: 30);

  // Modo de depuración
  static bool get isDebug => !kReleaseMode;

  // Puedes agregar más configuraciones específicas de Mostro aquí si las necesitas en el futuro
}
