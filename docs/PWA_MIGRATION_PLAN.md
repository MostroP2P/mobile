# Mostro Mobile → PWA Migration Plan

> **Objetivo**: Hacer que la app Flutter compile y funcione en web como PWA sin modificar las implementaciones móviles existentes, usando conditional imports y abstracciones.
>
> **Estrategia**: Additive-only — no se toca código mobile existente, solo se agregan archivos `_web.dart`, `_stub.dart` e interfaces.
>
> **Fecha**: Febrero 2026

---

## Tabla de Contenidos

- [Estado Actual](#estado-actual)
- [Phase 1: Compilación Web Básica](#phase-1-compilación-web-básica)
- [Phase 2: Persistencia Web](#phase-2-persistencia-web)
- [Phase 3: Conectividad Nostr en Web](#phase-3-conectividad-nostr-en-web)
- [Phase 4: Servicios Degradados Gracefully](#phase-4-servicios-degradados-gracefully)
- [Phase 5: Archivos y Media en Web](#phase-5-archivos-y-media-en-web)
- [Phase 6: PWA Completa](#phase-6-pwa-completa)
- [Archivos Nuevos por Phase](#archivos-nuevos-por-phase)
- [Riesgos y Decisiones Pendientes](#riesgos-y-decisiones-pendientes)

---

## Estado Actual

### Lo que ya existe para web
- `web/index.html` — template HTML de Flutter
- `web/manifest.json` — manifest PWA con iconos 192/512
- `web/icons/` — Icon-192, Icon-512, maskable variants
- `sembast_web: ^2.4.1` en pubspec.yaml (pero no se usa)
- `flutter_secure_storage: ^10.0.0-beta.4` (tiene soporte web)
- `shared_preferences` (tiene soporte web)
- Chrome detectado como device disponible

### Bloqueadores identificados (12 archivos, ~30 issues)

| # | Archivo | Problema | Severidad |
|---|---------|----------|-----------|
| 1 | `lib/main.dart` | `import 'dart:io'`, BiometricsHelper, BackgroundService, Platform checks | Crítica |
| 2 | `lib/background/background_service.dart` | `throw UnsupportedError` en web, `Platform.isAndroid` | Crítica |
| 3 | `lib/shared/providers/mostro_database_provider.dart` | `sembast_io`, `path_provider` filesystem | Crítica |
| 4 | `lib/features/relays/relays_notifier.dart` | `dart:io.WebSocket.connect()` en L275 | Alta |
| 5 | `lib/services/fcm_service.dart` | `dart:io`, `Platform.isLinux`, `FlutterBackgroundService` | Alta |
| 6 | `lib/services/push_notification_service.dart` | `dart:io show Platform` | Alta |
| 7 | `lib/services/lifecycle_manager.dart` | `dart:io`, `Platform.isAndroid` en L25 | Alta |
| 8 | `lib/shared/utils/notification_permission_helper.dart` | `dart:io`, `permission_handler` | Alta |
| 9 | `lib/shared/utils/biometrics_helper.dart` | `local_auth` sin soporte web real | Alta |
| 10 | `lib/services/logger_export_service.dart` | `dart:io.File`, `getTemporaryDirectory` | Alta |
| 11 | `lib/services/encrypted_file_upload_service.dart` | `dart:io.File` como parámetro | Alta |
| 12 | `lib/features/chat/widgets/encrypted_file_message.dart` | `dart:io`, `open_file`, `path_provider` | Alta |
| 13 | `lib/features/chat/widgets/encrypted_image_message.dart` | `dart:io`, `open_file`, `path_provider` | Alta |
| 14 | `lib/services/deep_link_service.dart` | `app_links` (soporte web limitado) | Baja |

---

## Phase 1: Compilación Web Básica

> **Meta**: Que `fvm flutter build web` compile sin errores.
> **Esfuerzo estimado**: 3-5 días
> **Resultado**: La app abre en Chrome, aunque varios features no funcionen aún.

### 1.1 — Crear stubs para `dart:io`

El problema principal es que `dart:io` no existe en web. Necesitamos un stub que provea las clases usadas (`Platform`, `WebSocket`, `File`) con implementaciones vacías para que compile.

**Crear**: `lib/shared/platform/io_stub.dart`

```dart
/// Stub para dart:io que permite compilar en web.
/// Estas clases nunca se ejecutan en web — solo satisfacen al compiler.

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isLinux => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static Map<String, String> get environment => {};
}

class WebSocket {
  static Future<WebSocket> connect(
    String url, {
    Map<String, dynamic>? headers,
  }) async {
    throw UnsupportedError('WebSocket.connect not available on web');
  }

  void add(dynamic data) {}
  Stream<dynamic> listen(void Function(dynamic)? onData) => const Stream.empty();
  Future<void> close([int? code, String? reason]) async {}
}

class File {
  final String path;
  File(this.path);
  Future<File> writeAsBytes(List<int> bytes) async => this;
  Future<File> writeAsString(String contents) async => this;
  Future<List<int>> readAsBytes() async => [];
  Future<String> readAsString() async => '';
  bool existsSync() => false;
  int lengthSync() => 0;
}

Future<Directory> getTemporaryDirectory() async {
  throw UnsupportedError('getTemporaryDirectory not available on web');
}

class Directory {
  final String path;
  Directory(this.path);
}
```

### 1.2 — Aplicar conditional imports a archivos con `dart:io`

Para cada archivo que importa `dart:io`, reemplazar:

```dart
// ANTES
import 'dart:io';

// DESPUÉS
import 'dart:io'
    if (dart.library.html) 'package:mostro_mobile/shared/platform/io_stub.dart';
```

**Archivos a modificar** (cambio mínimo — solo la línea del import):

| Archivo | Línea actual | Cambio |
|---------|-------------|--------|
| `lib/main.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/background/background_service.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/features/relays/relays_notifier.dart` | L2: `import 'dart:io';` | Conditional import |
| `lib/services/fcm_service.dart` | L2: `import 'dart:io';` | Conditional import |
| `lib/services/push_notification_service.dart` | L2: `import 'dart:io' show Platform;` | Conditional import |
| `lib/services/lifecycle_manager.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/shared/utils/notification_permission_helper.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/services/logger_export_service.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/services/encrypted_file_upload_service.dart` | L1: `import 'dart:io';` | Conditional import |
| `lib/features/chat/widgets/encrypted_file_message.dart` | L3: `import 'dart:io';` | Conditional import |
| `lib/features/chat/widgets/encrypted_image_message.dart` | L3: `import 'dart:io';` | Conditional import |

**Total**: 11 archivos, 1 línea por archivo.

### 1.3 — Background Service: factory web-safe

**Archivo actual**: `lib/background/background_service.dart`

```dart
// Código actual (L8-16)
BackgroundService createBackgroundService(Settings settings) {
  if (kIsWeb) {
    throw UnsupportedError('Background services are not supported on web');
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileBackgroundService(settings);
  } else {
    return DesktopBackgroundService();
  }
}
```

**Cambio**: Reemplazar `throw` por un NoOp service.

**Crear**: `lib/background/web_background_service.dart`

```dart
import 'package:mostro_mobile/background/abstract_background_service.dart';

/// No-op background service para web.
/// Web no soporta background services nativos.
class WebBackgroundService implements BackgroundService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  // Implementar todos los métodos de BackgroundService como no-op
}
```

**Modificar** `background_service.dart`:

```dart
BackgroundService createBackgroundService(Settings settings) {
  if (kIsWeb) {
    return WebBackgroundService();  // ← No-op en vez de throw
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileBackgroundService(settings);
  } else {
    return DesktopBackgroundService();
  }
}
```

### 1.4 — BiometricsHelper: factory web-safe

**Archivo actual**: `lib/shared/utils/biometrics_helper.dart`

`local_auth` tiene stubs web, pero la clase no se puede instanciar en web de forma útil.

**Crear**: `lib/shared/utils/biometrics_helper_web.dart`

```dart
/// Web stub: biometrics no disponibles en browser.
class BiometricsHelper {
  Future<bool> isBiometricsAvailable() async => false;
  Future<bool> authenticateWithBiometrics() async => true; // Skip auth en web
}
```

**Crear**: `lib/shared/utils/biometrics_helper_stub.dart`

```dart
/// Stub — nunca se ejecuta, solo satisface conditional import.
class BiometricsHelper {
  Future<bool> isBiometricsAvailable() async => false;
  Future<bool> authenticateWithBiometrics() async => false;
}
```

**Modificar** el import en `main.dart` (o donde se importe):

```dart
import 'package:mostro_mobile/shared/utils/biometrics_helper_stub.dart'
    if (dart.library.io) 'package:mostro_mobile/shared/utils/biometrics_helper.dart'
    if (dart.library.html) 'package:mostro_mobile/shared/utils/biometrics_helper_web.dart';
```

### 1.5 — Notification Permission: web-safe

**Archivo actual**: `lib/shared/utils/notification_permission_helper.dart` (12 líneas)

Usa `dart:io` Platform y `permission_handler`.

**Crear**: `lib/shared/utils/notification_permission_helper_web.dart`

```dart
/// Web: notifications use browser Notification API, no permission_handler needed.
Future<void> requestNotificationPermissionIfNeeded() async {
  // No-op en web. Browser permissions se manejan diferente.
}
```

**Crear**: `lib/shared/utils/notification_permission_helper_stub.dart`

```dart
Future<void> requestNotificationPermissionIfNeeded() async {}
```

**Modificar** el import en `main.dart`:

```dart
import 'package:mostro_mobile/shared/utils/notification_permission_helper_stub.dart'
    if (dart.library.io) 'package:mostro_mobile/shared/utils/notification_permission_helper.dart'
    if (dart.library.html) 'package:mostro_mobile/shared/utils/notification_permission_helper_web.dart';
```

### 1.6 — Verificación Phase 1

```bash
# Debe compilar sin errores
fvm flutter build web --release

# Debe abrir en Chrome (aunque features no funcionen)
fvm flutter run -d chrome
```

**Criterio de éxito**: Zero compilation errors. La app abre y muestra al menos la pantalla de login/splash.

---

## Phase 2: Persistencia Web

> **Meta**: Base de datos y storage funcionando en web.
> **Esfuerzo estimado**: 2-3 días
> **Resultado**: La app puede guardar/leer datos en web usando IndexedDB.

### 2.1 — Sembast: conditional factory

**Archivo actual**: `lib/shared/providers/mostro_database_provider.dart`

```dart
// Código actual (L1-14)
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openMostroDatabase(String dbName) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'mostro', 'databases', dbName);
  final db = await databaseFactoryIo.openDatabase(path);
  return db;
}
```

**Estrategia**: Crear 3 archivos con conditional import.

**Crear**: `lib/shared/providers/database_factory.dart` (entry point)

```dart
export 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_mobile.dart'
    if (dart.library.html) 'database_factory_web.dart';
```

**Crear**: `lib/shared/providers/database_factory_stub.dart`

```dart
import 'package:sembast/sembast.dart';

Future<Database> openMostroDatabase(String dbName) async {
  throw UnsupportedError('Platform not supported');
}
```

**Crear**: `lib/shared/providers/database_factory_mobile.dart`

```dart
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast/sembast.dart';

Future<Database> openMostroDatabase(String dbName) async {
  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'mostro', 'databases', dbName);
  final db = await databaseFactoryIo.openDatabase(path);
  return db;
}
```

**Crear**: `lib/shared/providers/database_factory_web.dart`

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

Future<Database> openMostroDatabase(String dbName) async {
  // Usa IndexedDB en web
  final db = await databaseFactoryWeb.openDatabase('mostro_$dbName');
  return db;
}
```

**Modificar**: `lib/shared/providers/mostro_database_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
// Reemplazar imports de sembast_io y path_provider por:
import 'package:mostro_mobile/shared/providers/database_factory.dart';

// El provider solo llama a openMostroDatabase() que ya resuelve la plataforma
```

### 2.2 — Verificar flutter_secure_storage web

`flutter_secure_storage: ^10.0.0-beta.4` ya tiene soporte web. Verificar que `key_storage.dart` funciona sin cambios.

**Acción**: Test manual en Chrome.

```dart
// key_storage.dart ya usa:
final FlutterSecureStorage secureStorage;
// Esto debería funcionar en web usando localStorage cifrado.
```

**Nota importante**: En web, `flutter_secure_storage` usa `localStorage` internamente. No es tan seguro como Keychain/Keystore en mobile. Para Phase 1 es aceptable, pero hay que documentar esta limitación.

**Posible configuración necesaria en `web/index.html`** — verificar si necesita script adicional para web crypto.

### 2.3 — SharedPreferences web

Ya funciona. No requiere cambios. `shared_preferences` usa `localStorage` en web automáticamente.

### 2.4 — Verificación Phase 2

```bash
fvm flutter run -d chrome
```

**Criterio de éxito**:
- La app puede crear y leer sesiones de la base de datos
- Settings se persisten entre recargas
- Keys se almacenan y recuperan correctamente

---

## Phase 3: Conectividad Nostr en Web

> **Meta**: WebSocket connections a relays funcionando en web.
> **Esfuerzo estimado**: 3-5 días
> **Resultado**: La app puede conectarse a relays Nostr y enviar/recibir eventos.

### 3.1 — Verificar `dart_nostr` en web

**Investigación necesaria**: El paquete `dart_nostr` puede ya usar `web_socket_channel` internamente (que es cross-platform). Si es así, la conectividad Nostr básica podría funcionar sin cambios.

**Acción**: Verificar si `dart_nostr` importa `dart:io` directamente o usa abstracción.

```bash
# Verificar dependencias de dart_nostr
fvm flutter pub deps | grep nostr
# Revisar si usa web_socket_channel
```

**Escenarios**:

- **Si `dart_nostr` ya soporta web**: No hay trabajo adicional para la conectividad principal.
- **Si NO soporta web**: Necesitamos un fork o un wrapper que use `web_socket_channel`.

### 3.2 — Relay validation WebSocket: abstracción

**Archivo**: `lib/features/relays/relays_notifier.dart` L271-317

El método `_testBasicWebSocketConnectivity()` usa `dart:io.WebSocket.connect()` directamente.

**Estrategia**: Reemplazar con `web_socket_channel` que es cross-platform.

**Agregar dependencia** en `pubspec.yaml`:

```yaml
dependencies:
  web_socket_channel: ^3.0.1
```

**Crear**: `lib/shared/platform/websocket_helper.dart`

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

/// Cross-platform WebSocket connectivity test.
/// Funciona en mobile, desktop Y web.
Future<bool> testWebSocketConnectivity(String url) async {
  try {
    final uri = Uri.parse(url);
    final channel = WebSocketChannel.connect(uri);

    const testReq = '["REQ", "test_conn", {"kinds":[1], "limit":1}]';
    channel.sink.add(testReq);

    bool receivedResponse = false;

    await for (final message in channel.stream.timeout(
      const Duration(seconds: 8),
      onTimeout: (sink) => sink.close(),
    )) {
      if (message.toString().startsWith('["')) {
        receivedResponse = true;
        break;
      }
    }

    await channel.sink.close();
    return receivedResponse;
  } catch (e) {
    return false;
  }
}
```

**Modificar** `relays_notifier.dart`:
- Reemplazar `_testBasicWebSocketConnectivity()` con llamada al helper cross-platform
- Eliminar el `import 'dart:io'` (ya no necesario tras reemplazar WebSocket)

### 3.3 — NostrService: verificar conectividad web

**Archivo**: `lib/services/nostr_service.dart`

Verificar que `NostrService` no use `dart:io` directamente. Si usa `dart_nostr` internamente, depende de si ese paquete soporta web.

**Acción**: Revisar imports de `nostr_service.dart` y las clases de `dart_nostr` que usa.

### 3.4 — SubscriptionManager: verificar web compatibility

**Archivo**: `lib/features/subscriptions/subscription_manager.dart`

Verificar que no tenga dependencias `dart:io`. Si solo depende de `dart_nostr` y Riverpod, debería funcionar.

### 3.5 — Verificación Phase 3

```bash
fvm flutter run -d chrome
```

**Criterio de éxito**:
- La app se conecta a al menos un relay Nostr
- Puede suscribirse y recibir eventos
- El order book muestra órdenes
- La validación de relays funciona en web

---

## Phase 4: Servicios Degradados Gracefully

> **Meta**: Servicios mobile-only funcionan en modo degradado en web sin crashear.
> **Esfuerzo estimado**: 3-4 días
> **Resultado**: Push notifications, lifecycle, FCM operan como no-op en web.

### 4.1 — FCM Service: web no-op

**Archivo**: `lib/services/fcm_service.dart`

Ya tiene guards `if (kIsWeb || Platform.isLinux) return;` pero importa `dart:io`.

**Cambio mínimo**: Con el conditional import de Phase 1 (1.2), el Platform del stub retornará false para todas las plataformas. El guard `kIsWeb` ya cubre web.

**Verificar**: Que la inicialización de Firebase no crashee en web. Firebase tiene soporte web pero la configuración puede diferir.

**Acción**: Verificar que `firebase_options.dart` tenga configuración web. Si no existe, hay que generarla:

```bash
flutterfire configure --platforms=web
```

**Crear** (si no existe): Configuración Firebase para web en `web/index.html`:

```html
<!-- Antes del script de flutter_bootstrap.js -->
<script src="https://www.gstatic.com/firebasejs/10.x.x/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.x.x/firebase-messaging-compat.js"></script>
```

### 4.2 — Push Notification Service: ya web-safe

**Archivo**: `lib/services/push_notification_service.dart`

Ya tiene `if (kIsWeb) return false;` en `isSupported`. Con el conditional import de Phase 1, compila sin problemas. No requiere cambios adicionales.

### 4.3 — Lifecycle Manager: web adaptation

**Archivo**: `lib/services/lifecycle_manager.dart` L24-45

```dart
// Código actual
if (Platform.isAndroid || Platform.isIOS) {
  switch (state) { ... }
}
```

**Cambio**: Agregar guard `kIsWeb` antes del Platform check.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

@override
void didChangeAppLifecycleState(AppLifecycleState state) async {
  if (kIsWeb) return;  // ← Agregar esta línea
  if (Platform.isAndroid || Platform.isIOS) {
    switch (state) { ... }
  }
}
```

**Nota**: En web, `didChangeAppLifecycleState` sí se llama (page visibility), pero el comportamiento actual (background/foreground switching de Nostr connections) puede no ser adecuado para web. Por ahora, skip.

### 4.4 — Logger Export Service: web alternative

**Archivo**: `lib/services/logger_export_service.dart`

Usa `dart:io.File`, `getTemporaryDirectory()`, `FilePicker`, `share_plus`.

**Estrategia**: Conditional import con implementación web que usa descarga de blob.

**Crear**: `lib/services/logger_export_service_web.dart`

```dart
import 'dart:typed_data';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:mostro_mobile/services/logger_service.dart';

class LoggerExportService {
  // En web, descarga el archivo directamente al browser
  static Future<String?> exportLogsToFolder(
    List<LogEntry> logs,
    LogExportStrings strings,
  ) async {
    final content = _logsToText(logs, strings);
    final bytes = Uint8List.fromList(utf8.encode(content));
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..setAttribute('download', _generateFilename())
      ..click();
    html.Url.revokeObjectUrl(url);
    return 'downloaded';
  }

  // share no disponible en web — usar misma descarga
  static Future<void> shareLogFile(
    List<LogEntry> logs,
    LogExportStrings strings,
  ) async {
    await exportLogsToFolder(logs, strings);
  }

  static String _generateFilename() {
    final now = DateTime.now();
    return 'mostro_logs_${now.toIso8601String().replaceAll(':', '-')}.txt';
  }

  static String _logsToText(List<LogEntry> logs, LogExportStrings strings) {
    // Misma lógica de formateo que la versión mobile
    final buffer = StringBuffer();
    for (final log in logs) {
      buffer.writeln('[${log.timestamp}] [${log.level}] ${log.message}');
    }
    return buffer.toString();
  }
}
```

**Crear**: `lib/services/logger_export_service_stub.dart` (stub)

**Modificar** imports donde se use `logger_export_service.dart` con conditional import.

### 4.5 — Deep Link Service: web adaptation

**Archivo**: `lib/services/deep_link_service.dart`

`app_links` tiene soporte web limitado. En web, los deep links son simplemente URLs.

**Cambio**: Agregar guard en `initialize()`:

```dart
Future<void> initialize() async {
  if (kIsWeb) {
    // En web, GoRouter ya maneja URLs. No necesitamos app_links.
    _isInitialized = true;
    return;
  }
  // ... resto del código actual
}
```

### 4.6 — Verificación Phase 4

```bash
fvm flutter run -d chrome
```

**Criterio de éxito**:
- La app no crashea al inicializar servicios en web
- Log export funciona descargando archivo en browser
- Lifecycle events no causan errores
- La app se comporta normalmente tras minimizar/restaurar tab

---

## Phase 5: Archivos y Media en Web

> **Meta**: Chat con archivos e imágenes funciona en web.
> **Esfuerzo estimado**: 4-5 días
> **Resultado**: Usuarios pueden enviar/recibir archivos e imágenes en chat desde web.

### 5.1 — Encrypted File Upload Service: interfaz abstracta

**Archivo**: `lib/services/encrypted_file_upload_service.dart`

El problema principal: usa `dart:io.File` como tipo de parámetro.

**Estrategia**: Cambiar a `Uint8List` como tipo universal, agregar metadata por separado.

**Crear**: `lib/services/file_data.dart` (modelo cross-platform)

```dart
/// Representación cross-platform de un archivo.
/// Evita dependencia en dart:io.File.
class FileData {
  final String filename;
  final Uint8List bytes;
  final String? mimeType;
  final int size;

  FileData({
    required this.filename,
    required this.bytes,
    this.mimeType,
    int? size,
  }) : size = size ?? bytes.length;
}
```

**Impacto**: Los métodos de upload/download que reciben `File` necesitan aceptar `FileData` o `Uint8List` en su lugar. Esto es un cambio de API pero no rompe mobile si se agregan overloads.

### 5.2 — File Message Widget: web implementation

**Archivo**: `lib/features/chat/widgets/encrypted_file_message.dart`

Usa `dart:io.File`, `path_provider`, `open_file`.

**Estrategia para web**:
- **Subida**: `file_picker` ya funciona en web para seleccionar archivos (devuelve `Uint8List`)
- **Descarga/apertura**: En vez de guardar a filesystem y abrir con `open_file`, descargar como blob

**Crear**: `lib/features/chat/widgets/file_operations_web.dart`

```dart
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

Future<void> openFileInBrowser(Uint8List bytes, String filename, String? mimeType) async {
  final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}
```

**Crear**: `lib/features/chat/widgets/file_operations_mobile.dart`

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> openFileOnDevice(Uint8List bytes, String filename, String? mimeType) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsBytes(bytes);
  await OpenFile.open(tempFile.path);
}
```

**Crear**: `lib/features/chat/widgets/file_operations_stub.dart`

```dart
import 'dart:typed_data';

Future<void> openFileOnPlatform(Uint8List bytes, String filename, String? mimeType) async {
  throw UnsupportedError('Platform not supported');
}
```

**Crear**: `lib/features/chat/widgets/file_operations.dart` (entry point)

```dart
export 'file_operations_stub.dart'
    if (dart.library.io) 'file_operations_mobile.dart'
    if (dart.library.html) 'file_operations_web.dart';
```

### 5.3 — Image Message Widget: web implementation

**Archivo**: `lib/features/chat/widgets/encrypted_image_message.dart`

Mismo patrón que file message. Usa `dart:io.File`, `path_provider`, `open_file`.

**Estrategia para web**:
- Las imágenes cifradas se descargan como `Uint8List` (ya cross-platform)
- Mostrar imagen: `Image.memory(bytes)` funciona en web
- Abrir/guardar: Usar misma estrategia de blob download

**Cambios**: Reusar `file_operations.dart` de 5.2 para la funcionalidad de abrir/guardar.

### 5.4 — File Validation Service: verificar web compatibility

**Archivo**: `lib/services/file_validation_service.dart`

Verificar si usa `dart:io.File`. Si es así, necesita adaptación similar a 5.1 para aceptar `FileData` o `Uint8List`.

### 5.5 — Image Picker: web alternative

El paquete `image_picker` tiene soporte web limitado. En web, usa `<input type="file">` internamente.

**Verificar**: Si `image_picker` ya funciona en web o si necesitamos usar `file_picker` como alternativa universal.

### 5.6 — Verificación Phase 5

```bash
fvm flutter run -d chrome
```

**Criterio de éxito**:
- Usuarios pueden enviar archivos en chat desde web
- Usuarios pueden enviar imágenes en chat desde web
- Archivos recibidos se pueden descargar en web
- Imágenes recibidas se muestran correctamente en web

---

## Phase 6: PWA Completa

> **Meta**: PWA instalable con service worker, offline support, y web notifications.
> **Esfuerzo estimado**: 3-5 días
> **Resultado**: La app es instalable como PWA con experiencia nativa.

### 6.1 — Actualizar `web/manifest.json`

```json
{
  "name": "Mostro P2P",
  "short_name": "Mostro",
  "start_url": ".",
  "display": "standalone",
  "background_color": "#1a1a2e",
  "theme_color": "#7b2ff7",
  "description": "Non-custodial Lightning Network P2P exchange over Nostr",
  "orientation": "portrait-primary",
  "prefer_related_applications": false,
  "categories": ["finance", "utilities"],
  "icons": [
    {
      "src": "icons/Icon-192.png",
      "sizes": "192x192",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-512.png",
      "sizes": "512x512",
      "type": "image/png"
    },
    {
      "src": "icons/Icon-maskable-192.png",
      "sizes": "192x192",
      "type": "image/png",
      "purpose": "maskable"
    },
    {
      "src": "icons/Icon-maskable-512.png",
      "sizes": "512x512",
      "type": "image/png",
      "purpose": "maskable"
    }
  ]
}
```

### 6.2 — Service Worker para offline

Flutter genera `flutter_service_worker.js` automáticamente. Para PWA completa:

**Modificar** `web/index.html`:

```html
<script>
  // Register Flutter service worker
  if ('serviceWorker' in navigator) {
    window.addEventListener('flutter-first-frame', function () {
      navigator.serviceWorker.register('flutter_service_worker.js');
    });
  }
</script>
```

### 6.3 — Web Push Notifications

En web, las push notifications usan la Web Push API, no FCM directamente.

**Opción A**: Firebase Cloud Messaging para Web (ya soporta web push)
- Requiere `firebase-messaging-sw.js` service worker
- Se configura con VAPID key

**Opción B**: Web Notifications API directamente
- Más simple, sin dependencia de Firebase
- Solo funciona mientras la app está abierta (no background)

**Crear**: `web/firebase-messaging-sw.js` (si se usa Firebase)

```javascript
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.x.x/firebase-messaging-compat.js');

firebase.initializeApp({
  // Config from firebase_options.dart
  apiKey: "...",
  projectId: "...",
  messagingSenderId: "...",
  appId: "...",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  console.log('Background message:', message);
  const notificationTitle = message.notification?.title ?? 'Mostro';
  const notificationOptions = {
    body: message.notification?.body ?? '',
    icon: '/icons/Icon-192.png',
  };
  return self.registration.showNotification(notificationTitle, notificationOptions);
});
```

### 6.4 — Actualizar `web/index.html` metadata

```html
<head>
  <!-- PWA meta tags -->
  <meta name="theme-color" content="#7b2ff7">
  <meta name="description" content="Mostro - Non-custodial Lightning P2P exchange over Nostr">

  <!-- iOS PWA meta tags -->
  <meta name="mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-capable" content="yes">
  <meta name="apple-mobile-web-app-status-bar-style" content="black-translucent">
  <meta name="apple-mobile-web-app-title" content="Mostro">
  <link rel="apple-touch-icon" href="icons/Icon-192.png">

  <!-- Favicon -->
  <link rel="icon" type="image/png" sizes="32x32" href="favicon.png">

  <title>Mostro P2P</title>
  <link rel="manifest" href="manifest.json">
</head>
```

### 6.5 — Build y deploy web

```bash
# Build optimizado para web
fvm flutter build web --release --web-renderer canvaskit

# O con HTML renderer (más ligero, mejor SEO)
fvm flutter build web --release --web-renderer html

# El output está en build/web/
```

**Opciones de web renderer**:
- **CanvasKit**: Rendering más fiel a mobile, más pesado (~2MB), mejor para apps complejas
- **HTML**: Más ligero (~400KB), usa HTML/CSS/Canvas, puede tener diferencias visuales
- **auto** (default): CanvasKit en desktop, HTML en mobile browsers

**Recomendación para Mostro**: `canvaskit` por consistencia visual con mobile.

### 6.6 — Verificación Phase 6

**Tests manuales**:
1. Abrir en Chrome → Verificar ícono "Install" en address bar
2. Instalar como PWA → Verificar que abre como app standalone
3. Verificar offline: desconectar internet → la app debe mostrar cached content
4. Verificar notificaciones web push
5. Verificar en mobile browsers (Chrome Android, Safari iOS)

**Lighthouse audit**:
```bash
# En Chrome DevTools → Lighthouse → Progressive Web App
# Target: Score > 90
```

---

## Archivos Nuevos por Phase

### Phase 1 (7 archivos nuevos, 11 archivos modificados)

| Acción | Archivo |
|--------|---------|
| **Crear** | `lib/shared/platform/io_stub.dart` |
| **Crear** | `lib/background/web_background_service.dart` |
| **Crear** | `lib/shared/utils/biometrics_helper_web.dart` |
| **Crear** | `lib/shared/utils/biometrics_helper_stub.dart` |
| **Crear** | `lib/shared/utils/notification_permission_helper_web.dart` |
| **Crear** | `lib/shared/utils/notification_permission_helper_stub.dart` |
| **Modificar** | 11 archivos — agregar conditional import de `dart:io` (1 línea cada uno) |
| **Modificar** | `lib/background/background_service.dart` — WebBackgroundService en vez de throw |
| **Modificar** | `lib/main.dart` — conditional imports para biometrics y notification helper |

### Phase 2 (4 archivos nuevos, 1 archivo modificado)

| Acción | Archivo |
|--------|---------|
| **Crear** | `lib/shared/providers/database_factory.dart` |
| **Crear** | `lib/shared/providers/database_factory_stub.dart` |
| **Crear** | `lib/shared/providers/database_factory_mobile.dart` |
| **Crear** | `lib/shared/providers/database_factory_web.dart` |
| **Modificar** | `lib/shared/providers/mostro_database_provider.dart` — usar factory |

### Phase 3 (1-2 archivos nuevos, 1-2 archivos modificados)

| Acción | Archivo |
|--------|---------|
| **Crear** | `lib/shared/platform/websocket_helper.dart` |
| **Modificar** | `lib/features/relays/relays_notifier.dart` — usar websocket_helper |
| **Modificar** | `pubspec.yaml` — agregar `web_socket_channel` |

### Phase 4 (3-4 archivos nuevos, 2-3 archivos modificados)

| Acción | Archivo |
|--------|---------|
| **Crear** | `lib/services/logger_export_service_web.dart` |
| **Crear** | `lib/services/logger_export_service_stub.dart` |
| **Modificar** | `lib/services/lifecycle_manager.dart` — agregar kIsWeb guard |
| **Modificar** | `lib/services/deep_link_service.dart` — agregar kIsWeb guard |
| **Posible** | Firebase web configuration files |

### Phase 5 (6-8 archivos nuevos, 3-4 archivos modificados)

| Acción | Archivo |
|--------|---------|
| **Crear** | `lib/services/file_data.dart` |
| **Crear** | `lib/features/chat/widgets/file_operations.dart` |
| **Crear** | `lib/features/chat/widgets/file_operations_web.dart` |
| **Crear** | `lib/features/chat/widgets/file_operations_mobile.dart` |
| **Crear** | `lib/features/chat/widgets/file_operations_stub.dart` |
| **Modificar** | `lib/features/chat/widgets/encrypted_file_message.dart` |
| **Modificar** | `lib/features/chat/widgets/encrypted_image_message.dart` |
| **Modificar** | `lib/services/encrypted_file_upload_service.dart` |

### Phase 6 (1-2 archivos nuevos, 2-3 archivos modificados)

| Acción | Archivo |
|--------|---------|
| **Posible** | `web/firebase-messaging-sw.js` |
| **Modificar** | `web/manifest.json` |
| **Modificar** | `web/index.html` |

### Total estimado
- **~22-28 archivos nuevos**
- **~20-25 archivos modificados**
- **0 archivos mobile eliminados o reescritos**

---

## Riesgos y Decisiones Pendientes

### Riesgo Alto

| Riesgo | Descripción | Mitigación |
|--------|-------------|------------|
| **`dart_nostr` web support** | No está confirmado que `dart_nostr` funcione en web. Si usa `dart:io` internamente para WebSocket, es un blocker grande. | Investigar en Phase 3. Si no soporta, evaluar fork o paquete alternativo (`nostr_tools`, `ndk`). |
| **Key security en web** | `flutter_secure_storage` usa `localStorage` en web, que es visible en DevTools. Para una app de trading P2P, esto es un riesgo de seguridad. | Phase 2: Documentar limitación. Futuro: Implementar Web Crypto API + IndexedDB cifrado. |
| **Performance web** | Flutter web con CanvasKit puede ser pesado (~2MB initial load). Para mercados emergentes con conexiones lentas, esto es un problema. | Evaluar HTML renderer. Implementar lazy loading. Optimizar assets. |

### Riesgo Medio

| Riesgo | Descripción | Mitigación |
|--------|-------------|------------|
| **`open_file` replacement** | En web no existe equivalente directo. Los archivos se descargan, no se "abren". | UX diferente aceptable: botón "Descargar" en vez de "Abrir". |
| **Background processing** | Web no tiene background services reales. Las conexiones WebSocket se pausan cuando el tab no está activo. | Aceptar limitación. Reconectar al volver al tab. Service Worker para notificaciones push. |
| **Firebase web config** | Si el proyecto no tiene Firebase configurado para web, requiere setup adicional en Firebase Console. | Verificar en Phase 4. Si no existe, configurar o usar Web Notifications API directamente. |

### Riesgo Bajo

| Riesgo | Descripción | Mitigación |
|--------|-------------|------------|
| **Deep links** | En web son simplemente URLs. `app_links` no aplica. | GoRouter ya maneja routing por URL. Solo necesita skip de app_links. |
| **Biometrics** | No existen en web. | Return true (skip auth) o usar PIN como alternativa. |
| **Permissions** | Web tiene su propio modelo de permisos. | `permission_handler` no-op en web. Usar browser Notification API cuando necesario. |

### Decisiones pendientes

1. **¿Qué web renderer usar?** — CanvasKit (fiel a mobile) vs HTML (más ligero)
2. **¿Qué hacer con key storage en web?** — localStorage aceptable para MVP, o implementar Web Crypto API desde el inicio
3. **¿Firebase o Web Push nativo?** — Firebase da FCM cross-platform, Web Push es más simple
4. **¿`dart_nostr` soporta web?** — Bloqueador potencial que debe investigarse antes de Phase 3
5. **¿PIN como alternativa a biometrics en web?** — UX decision
6. **¿Hosting?** — GitHub Pages, Vercel, Cloudflare Pages, self-hosted

---

## Orden de Ejecución Recomendado

```
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5 ──→ Phase 6
 3-5 días    2-3 días    3-5 días    3-4 días    4-5 días    3-5 días

 Compila      DB web     Nostr web   Services    Chat files   PWA full
 en web       funciona   funciona    no-crash    funciona     instalable
```

**Total estimado**: 18-27 días de desarrollo (1 desarrollador)

**Hito crítico**: Tras Phase 3, la app es funcional en web para el flujo core (ver órdenes, crear/tomar órdenes, chat de texto). Las phases 4-6 son mejoras incrementales.

---

## Notas para `dart:html` deprecation

A partir de Dart 3.x, `dart:html` está siendo reemplazado por el paquete `web`. Si la versión de Dart del proyecto es >= 3.3, considerar usar:

```dart
import 'package:web/web.dart' as web;
```

en lugar de:

```dart
import 'dart:html' as html;
```

Esto afecta las implementaciones web de Phase 4 y 5. Verificar la versión de Dart antes de implementar.
