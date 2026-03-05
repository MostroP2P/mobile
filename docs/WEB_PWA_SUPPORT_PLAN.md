# Web & PWA Support Plan

> **Goal**: Make the Flutter app compile and run on web as a PWA without modifying existing mobile implementations, using conditional imports and abstractions.
>
> **Strategy**: Additive-only — no existing mobile code is touched, only `_web.dart`, `_stub.dart` files and interfaces are added.
>
> **Date**: March 2026

---

## Table of Contents

- [Current State](#current-state)
- [Phase 1: Basic Web Compilation](#phase-1-basic-web-compilation)
- [Phase 2: Web Persistence](#phase-2-web-persistence)
- [Phase 3: Nostr Connectivity on Web](#phase-3-nostr-connectivity-on-web)
- [Phase 4: Gracefully Degraded Services](#phase-4-gracefully-degraded-services)
- [Phase 5: Files and Media on Web](#phase-5-files-and-media-on-web)
- [Phase 6: Full PWA](#phase-6-full-pwa)
- [New Files by Phase](#new-files-by-phase)
- [Risks and Pending Decisions](#risks-and-pending-decisions)

---

## Current State

### What already exists for web
- `web/index.html` — Flutter HTML template
- `web/manifest.json` — PWA manifest with 192/512 icons
- `web/icons/` — Icon-192, Icon-512, maskable variants
- `sembast_web: ^2.4.1` in pubspec.yaml (unused so far)
- `flutter_secure_storage: ^10.0.0-beta.4` (has web support)
- `shared_preferences` (has web support)
- Chrome detected as available device

### Identified blockers (14 files, ~30 issues)

| # | File | Problem | Severity |
|---|------|---------|----------|
| 1 | `lib/main.dart` | `import 'dart:io'`, BiometricsHelper, BackgroundService, Platform checks | Critical |
| 2 | `lib/background/background_service.dart` | `throw UnsupportedError` on web, `Platform.isAndroid` | Critical |
| 3 | `lib/shared/providers/mostro_database_provider.dart` | `sembast_io`, `path_provider` filesystem | Critical |
| 4 | `lib/features/relays/relays_notifier.dart` | `dart:io.WebSocket.connect()` at L275 | High |
| 5 | `lib/services/fcm_service.dart` | `dart:io`, `Platform.isLinux`, `FlutterBackgroundService` | High |
| 6 | `lib/services/push_notification_service.dart` | `dart:io show Platform` | High |
| 7 | `lib/services/lifecycle_manager.dart` | `dart:io`, `Platform.isAndroid` at L25 | High |
| 8 | `lib/shared/utils/notification_permission_helper.dart` | `dart:io`, `permission_handler` | High |
| 9 | `lib/shared/utils/biometrics_helper.dart` | `local_auth` with no real web support | High |
| 10 | `lib/services/logger_export_service.dart` | `dart:io.File`, `getTemporaryDirectory` | High |
| 11 | `lib/services/encrypted_file_upload_service.dart` | `dart:io.File` as parameter type | High |
| 12 | `lib/features/chat/widgets/encrypted_file_message.dart` | `dart:io`, `open_file`, `path_provider` | High |
| 13 | `lib/features/chat/widgets/encrypted_image_message.dart` | `dart:io`, `open_file`, `path_provider` | High |
| 14 | `lib/services/deep_link_service.dart` | `app_links` (limited web support) | Low |

---

## Phase 1: Basic Web Compilation

> **Goal**: `fvm flutter build web` compiles without errors.
> **Estimated effort**: 3-5 days
> **Outcome**: The app opens in Chrome, even though several features may not work yet.

### 1.1 — Create stubs for `dart:io`

The main problem is that `dart:io` does not exist on web. We need a stub that provides the used classes (`Platform`, `WebSocket`, `File`) with empty implementations so the compiler is satisfied.

**Create**: `lib/shared/platform/io_stub.dart`

```dart
/// Stub for dart:io that allows web compilation.
/// These classes never execute on web — they only satisfy the compiler.
import 'dart:async';

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
  StreamSubscription<dynamic> listen(
    void Function(dynamic)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => const Stream<dynamic>.empty().listen(onData);
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

class Directory {
  final String path;
  Directory(this.path);
}
```

**Create**: `lib/shared/platform/path_provider_stub.dart`

```dart
/// Stub for path_provider that allows web compilation.
/// These functions never execute on web — they only satisfy the compiler.

class Directory {
  final String path;
  Directory(this.path);
}

Future<Directory> getTemporaryDirectory() async {
  throw UnsupportedError('getTemporaryDirectory not available on web');
}

Future<Directory> getApplicationSupportDirectory() async {
  throw UnsupportedError('getApplicationSupportDirectory not available on web');
}
```

### 1.2 — Apply conditional imports to files with `dart:io`

For each file that imports `dart:io`, replace:

```dart
// BEFORE
import 'dart:io';

// AFTER
import 'dart:io'
    if (dart.library.js_interop) 'package:mostro_mobile/shared/platform/io_stub.dart';
```

**Files to modify** (minimal change — only the import line):

| File | Current line | Change |
|------|-------------|--------|
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

**Total**: 11 files, 1 line per file.

### 1.3 — Background Service: web-safe factory

**Current file**: `lib/background/background_service.dart`

```dart
// Current code (L8-16)
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

**Change**: Replace `throw` with a no-op service.

**Create**: `lib/background/web_background_service.dart`

```dart
import 'package:mostro_mobile/background/abstract_background_service.dart';

/// No-op background service for web.
/// Web does not support native background services.
class WebBackgroundService implements BackgroundService {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}

  // Implement all BackgroundService methods as no-op
}
```

**Modify** `background_service.dart`:

```dart
BackgroundService createBackgroundService(Settings settings) {
  if (kIsWeb) {
    return WebBackgroundService();  // No-op instead of throw
  }
  if (Platform.isAndroid || Platform.isIOS) {
    return MobileBackgroundService(settings);
  } else {
    return DesktopBackgroundService();
  }
}
```

### 1.4 — BiometricsHelper: web-safe factory

**Current file**: `lib/shared/utils/biometrics_helper.dart`

`local_auth` has web stubs, but the class cannot be usefully instantiated on web.

**Create**: `lib/shared/utils/biometrics_helper_web.dart`

```dart
/// Web stub: biometrics not available in browser.
/// isBiometricsAvailable() returns false, so authenticateWithBiometrics()
/// should never be called. Returns false as a safety measure.
class BiometricsHelper {
  Future<bool> isBiometricsAvailable() async => false;
  Future<bool> authenticateWithBiometrics() async => false; // Reject if somehow called
}
```

**Create**: `lib/shared/utils/biometrics_helper_stub.dart`

```dart
/// Stub — never executes, only satisfies conditional import.
class BiometricsHelper {
  Future<bool> isBiometricsAvailable() async => false;
  Future<bool> authenticateWithBiometrics() async => false;
}
```

**Modify** the import in `main.dart` (or wherever it is imported):

```dart
import 'package:mostro_mobile/shared/utils/biometrics_helper_stub.dart'
    if (dart.library.io) 'package:mostro_mobile/shared/utils/biometrics_helper.dart'
    if (dart.library.js_interop) 'package:mostro_mobile/shared/utils/biometrics_helper_web.dart';
```

### 1.5 — Notification Permission: web-safe

**Current file**: `lib/shared/utils/notification_permission_helper.dart` (12 lines)

Uses `dart:io` Platform and `permission_handler`.

**Create**: `lib/shared/utils/notification_permission_helper_web.dart`

```dart
/// Web: notifications use browser Notification API, no permission_handler needed.
Future<void> requestNotificationPermissionIfNeeded() async {
  // No-op on web. Browser permissions are handled differently.
}
```

**Create**: `lib/shared/utils/notification_permission_helper_stub.dart`

```dart
Future<void> requestNotificationPermissionIfNeeded() async {}
```

**Modify** the import in `main.dart`:

```dart
import 'package:mostro_mobile/shared/utils/notification_permission_helper_stub.dart'
    if (dart.library.io) 'package:mostro_mobile/shared/utils/notification_permission_helper.dart'
    if (dart.library.js_interop) 'package:mostro_mobile/shared/utils/notification_permission_helper_web.dart';
```

### 1.6 — Phase 1 Verification

```bash
# Must compile without errors
fvm flutter build web --release

# Must open in Chrome (even if features don't work yet)
fvm flutter run -d chrome
```

**Success criteria**: Zero compilation errors. The app opens and shows at least the login/splash screen.

---

## Phase 2: Web Persistence

> **Goal**: Database and storage working on web.
> **Estimated effort**: 2-3 days
> **Outcome**: The app can save/read data on web using IndexedDB.

### 2.1 — Sembast: conditional factory

**Current file**: `lib/shared/providers/mostro_database_provider.dart`

```dart
// Current code (L1-14)
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

**Strategy**: Create 3 files with conditional import.

**Create**: `lib/shared/providers/database_factory.dart` (entry point)

```dart
export 'database_factory_stub.dart'
    if (dart.library.io) 'database_factory_mobile.dart'
    if (dart.library.js_interop) 'database_factory_web.dart';
```

**Create**: `lib/shared/providers/database_factory_stub.dart`

```dart
import 'package:sembast/sembast.dart';

Future<Database> openMostroDatabase(String dbName) async {
  throw UnsupportedError('Platform not supported');
}
```

**Create**: `lib/shared/providers/database_factory_mobile.dart`

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

**Create**: `lib/shared/providers/database_factory_web.dart`

```dart
import 'package:sembast/sembast.dart';
import 'package:sembast_web/sembast_web.dart';

Future<Database> openMostroDatabase(String dbName) async {
  // Uses IndexedDB on web
  final db = await databaseFactoryWeb.openDatabase('mostro_$dbName');
  return db;
}
```

**Modify**: `lib/shared/providers/mostro_database_provider.dart`

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
// Replace sembast_io and path_provider imports with:
import 'package:mostro_mobile/shared/providers/database_factory.dart';

// The provider just calls openMostroDatabase() which already resolves the platform
```

### 2.2 — Verify flutter_secure_storage web support

`flutter_secure_storage: ^10.0.0-beta.4` already has web support. Verify that `key_storage.dart` works without changes.

**Action**: Manual test in Chrome.

```dart
// key_storage.dart already uses:
final FlutterSecureStorage secureStorage;
// This should work on web using encrypted localStorage.
```

**Important note**: On web, `flutter_secure_storage` uses `localStorage` internally. This is not as secure as Keychain/Keystore on mobile. Acceptable for Phase 1, but this limitation must be documented.

**Possible configuration needed in `web/index.html`** — verify if additional web crypto scripts are required.

### 2.3 — SharedPreferences web

Already works. No changes required. `shared_preferences` uses `localStorage` on web automatically.

### 2.4 — Phase 2 Verification

```bash
fvm flutter run -d chrome
```

**Success criteria**:
- The app can create and read sessions from the database
- Settings persist between reloads
- Keys are stored and retrieved correctly

---

## Phase 3: Nostr Connectivity on Web

> **Goal**: WebSocket connections to relays working on web.
> **Estimated effort**: 3-5 days
> **Outcome**: The app can connect to Nostr relays and send/receive events.

### 3.1 — Fix `dart_nostr` for web

**Status**: Investigated — `dart_nostr` does NOT compile for web, but the fix is minimal.

**Root cause**: 3 files have unused `dart:io` imports that break web compilation. The actual WebSocket implementation already uses `web_socket_channel` (cross-platform), so networking works fine.

| File | Line | Actually uses `dart:io`? |
|------|------|--------------------------|
| `lib/nostr/instance/registry.dart` | 1 | No — dead import |
| `lib/nostr/instance/relays/relays.dart` | 3 | No — dead import |
| `lib/nostr/model/relay.dart` | 3 | No — dead import |

**Fix**: Remove the 3 unused `import 'dart:io';` lines.

**Options to unblock**:
1. **Submit PR to `anasfik/nostr`** — trivial fix, likely quick merge
2. **Temporary fork** — while waiting for upstream merge
3. **Path dependency override** — point to a patched local copy in `pubspec_overrides.yaml`

### 3.2 — Relay validation WebSocket: abstraction

**File**: `lib/features/relays/relays_notifier.dart` L271-317

The `_testBasicWebSocketConnectivity()` method uses `dart:io.WebSocket.connect()` directly.

**Strategy**: Replace with `web_socket_channel` which is cross-platform.

**Add dependency** in `pubspec.yaml`:

```yaml
dependencies:
  web_socket_channel: ^3.0.1
```

**Create**: `lib/shared/platform/websocket_helper.dart`

```dart
import 'package:web_socket_channel/web_socket_channel.dart';

/// Cross-platform WebSocket connectivity test.
/// Works on mobile, desktop AND web.
Future<bool> testWebSocketConnectivity(String url) async {
  try {
    final uri = Uri.parse(url);
    final channel = WebSocketChannel.connect(uri);
    await channel.ready;

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

**Modify** `relays_notifier.dart`:
- Replace `_testBasicWebSocketConnectivity()` with a call to the cross-platform helper
- Remove the `import 'dart:io'` (no longer needed after replacing WebSocket)

### 3.3 — NostrService: verify web connectivity

**File**: `lib/services/nostr_service.dart`

Verify that `NostrService` does not use `dart:io` directly. If it uses `dart_nostr` internally, it depends on whether that package supports web.

**Action**: Review imports in `nostr_service.dart` and the `dart_nostr` classes it uses.

### 3.4 — SubscriptionManager: verify web compatibility

**File**: `lib/features/subscriptions/subscription_manager.dart`

Verify it has no `dart:io` dependencies. If it only depends on `dart_nostr` and Riverpod, it should work.

### 3.5 — Phase 3 Verification

```bash
fvm flutter run -d chrome
```

**Success criteria**:
- The app connects to at least one Nostr relay
- Can subscribe and receive events
- The order book shows orders
- Relay validation works on web

---

## Phase 4: Gracefully Degraded Services

> **Goal**: Mobile-only services run in degraded mode on web without crashing.
> **Estimated effort**: 3-4 days
> **Outcome**: Push notifications, lifecycle, FCM operate as no-op on web.

### 4.1 — FCM Service: web no-op

**File**: `lib/services/fcm_service.dart`

Already has guards `if (kIsWeb || Platform.isLinux) return;` but imports `dart:io`.

**Minimal change**: With the conditional import from Phase 1 (1.2), the stub's Platform will return false for all platforms. The `kIsWeb` guard already covers web.

**Verify**: That Firebase initialization doesn't crash on web. Firebase has web support but configuration may differ.

**Action**: Verify that `firebase_options.dart` has web configuration. If it doesn't exist, generate it:

```bash
flutterfire configure --platforms=web
```

**Create** (if needed): Firebase web configuration in `web/index.html`:

```html
<!-- Before the flutter_bootstrap.js script -->
<script src="https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js"></script>
```

### 4.2 — Push Notification Service: already web-safe

**File**: `lib/services/push_notification_service.dart`

Already has `if (kIsWeb) return false;` in `isSupported`. With the conditional import from Phase 1, it compiles without issues. No additional changes required.

### 4.3 — Lifecycle Manager: web adaptation

**File**: `lib/services/lifecycle_manager.dart` L24-45

```dart
// Current code
if (Platform.isAndroid || Platform.isIOS) {
  switch (state) { ... }
}
```

**Change**: Add `kIsWeb` guard before the Platform check.

```dart
import 'package:flutter/foundation.dart' show kIsWeb;

@override
void didChangeAppLifecycleState(AppLifecycleState state) async {
  if (kIsWeb) return;  // Add this line
  if (Platform.isAndroid || Platform.isIOS) {
    switch (state) { ... }
  }
}
```

**Note**: On web, `didChangeAppLifecycleState` is called (page visibility), but the current behavior (background/foreground switching of Nostr connections) may not be appropriate for web. Skip for now.

### 4.4 — Logger Export Service: web alternative

**File**: `lib/services/logger_export_service.dart`

Uses `dart:io.File`, `getTemporaryDirectory()`, `FilePicker`, `share_plus`.

**Strategy**: Conditional import with web implementation that uses blob download.

**Create**: `lib/services/logger_export_service_web.dart`

```dart
import 'dart:typed_data';
import 'dart:convert';
import 'package:web/web.dart' as web;
import 'package:mostro_mobile/services/logger_service.dart';

class LoggerExportService {
  // On web, download the file directly to the browser
  static Future<String?> exportLogsToFolder(
    List<LogEntry> logs,
    LogExportStrings strings,
  ) async {
    final content = _logsToText(logs, strings);
    final bytes = Uint8List.fromList(utf8.encode(content));
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'text/plain'));
    final url = web.URL.createObjectURL(blob);
    final anchor = web.HTMLAnchorElement()
      ..href = url
      ..download = _generateFilename();
    anchor.click();
    web.URL.revokeObjectURL(url);
    return 'downloaded';
  }

  // Share not available on web — use same download
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
    // Same formatting logic as the mobile version
    final buffer = StringBuffer();
    for (final log in logs) {
      buffer.writeln('[${log.timestamp}] [${log.level}] ${log.message}');
    }
    return buffer.toString();
  }
}
```

**Create**: `lib/services/logger_export_service_stub.dart` (stub)

**Modify** imports wherever `logger_export_service.dart` is used with conditional import.

### 4.5 — Deep Link Service: web adaptation

**File**: `lib/services/deep_link_service.dart`

`app_links` has limited web support. On web, deep links are simply URLs.

**Change**: Add guard in `initialize()`:

```dart
Future<void> initialize() async {
  if (kIsWeb) {
    // On web, GoRouter already handles URLs. We don't need app_links.
    _isInitialized = true;
    return;
  }
  // ... rest of current code
}
```

### 4.6 — Phase 4 Verification

```bash
fvm flutter run -d chrome
```

**Success criteria**:
- The app does not crash when initializing services on web
- Log export works by downloading a file in the browser
- Lifecycle events don't cause errors
- The app behaves normally after minimizing/restoring the tab

---

## Phase 5: Files and Media on Web

> **Goal**: Chat with files and images works on web.
> **Estimated effort**: 4-5 days
> **Outcome**: Users can send/receive files and images in chat from web.

### 5.1 — Encrypted File Upload Service: abstract interface

**File**: `lib/services/encrypted_file_upload_service.dart`

The main problem: uses `dart:io.File` as parameter type.

**Strategy**: Change to `Uint8List` as universal type, add metadata separately.

**Create**: `lib/services/file_data.dart` (cross-platform model)

```dart
import 'dart:typed_data';

/// Cross-platform file representation.
/// Avoids dependency on dart:io.File.
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

**Impact**: Upload/download methods that receive `File` need to accept `FileData` or `Uint8List` instead. This is an API change but doesn't break mobile if overloads are added.

### 5.2 — File Message Widget: web implementation

**File**: `lib/features/chat/widgets/encrypted_file_message.dart`

Uses `dart:io.File`, `path_provider`, `open_file`.

**Web strategy**:
- **Upload**: `file_picker` already works on web for file selection (returns `Uint8List`)
- **Download/open**: Instead of saving to filesystem and opening with `open_file`, download as blob

**Create**: `lib/features/chat/widgets/file_operations_web.dart`

```dart
import 'dart:typed_data';
import 'package:web/web.dart' as web;

Future<void> openFile(Uint8List bytes, String filename, String? mimeType) async {
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType ?? 'application/octet-stream'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = url
    ..download = filename;
  anchor.click();
  web.URL.revokeObjectURL(url);
}
```

**Create**: `lib/features/chat/widgets/file_operations_mobile.dart`

```dart
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

Future<void> openFile(Uint8List bytes, String filename, String? mimeType) async {
  final tempDir = await getTemporaryDirectory();
  final tempFile = File('${tempDir.path}/$filename');
  await tempFile.writeAsBytes(bytes);
  await OpenFile.open(tempFile.path);
}
```

**Create**: `lib/features/chat/widgets/file_operations_stub.dart`

```dart
import 'dart:typed_data';

Future<void> openFile(Uint8List bytes, String filename, String? mimeType) async {
  throw UnsupportedError('Platform not supported');
}
```

**Create**: `lib/features/chat/widgets/file_operations.dart` (entry point)

```dart
export 'file_operations_stub.dart'
    if (dart.library.io) 'file_operations_mobile.dart'
    if (dart.library.js_interop) 'file_operations_web.dart';
```

### 5.3 — Image Message Widget: web implementation

**File**: `lib/features/chat/widgets/encrypted_image_message.dart`

Same pattern as file message. Uses `dart:io.File`, `path_provider`, `open_file`.

**Web strategy**:
- Encrypted images are downloaded as `Uint8List` (already cross-platform)
- Display image: `Image.memory(bytes)` works on web
- Open/save: Use the same blob download strategy

**Changes**: Reuse `file_operations.dart` from 5.2 for open/save functionality.

### 5.4 — File Validation Service: verify web compatibility

**File**: `lib/services/file_validation_service.dart`

Verify if it uses `dart:io.File`. If so, it needs a similar adaptation to 5.1 to accept `FileData` or `Uint8List`.

### 5.5 — Image Picker: web alternative

The `image_picker` package has limited web support. On web, it uses `<input type="file">` internally.

**Verify**: Whether `image_picker` already works on web or if we need to use `file_picker` as a universal alternative.

### 5.6 — Phase 5 Verification

```bash
fvm flutter run -d chrome
```

**Success criteria**:
- Users can send files in chat from web
- Users can send images in chat from web
- Received files can be downloaded on web
- Received images display correctly on web

---

## Phase 6: Full PWA

> **Goal**: Installable PWA with service worker, offline support, and web notifications.
> **Estimated effort**: 3-5 days
> **Outcome**: The app is installable as a PWA with native-like experience.

### 6.1 — Update `web/manifest.json`

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

### 6.2 — Service Worker for offline

Flutter automatically generates `flutter_service_worker.js`. For full PWA:

**Modify** `web/index.html`:

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

On web, push notifications use the Web Push API, not FCM directly.

**Option A**: Firebase Cloud Messaging for Web (already supports web push)
- Requires `firebase-messaging-sw.js` service worker
- Configured with VAPID key

**Option B**: Web Notifications API directly
- Simpler, no Firebase dependency
- Only works while the app is open (no background)

**Create**: `web/firebase-messaging-sw.js` (if using Firebase)

```javascript
importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/12.3.0/firebase-messaging-compat.js');

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

### 6.4 — Update `web/index.html` metadata

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

### 6.5 — Web build and deploy

```bash
# Optimized web build
fvm flutter build web --release --web-renderer canvaskit

# Or with HTML renderer (lighter, better SEO)
fvm flutter build web --release --web-renderer html

# Output is in build/web/
```

**Web renderer options**:
- **CanvasKit**: Most faithful rendering to mobile, heavier (~2MB), better for complex apps
- **HTML**: Lighter (~400KB), uses HTML/CSS/Canvas, may have visual differences
- **auto** (default): CanvasKit on desktop, HTML on mobile browsers

**Recommendation for Mostro**: `canvaskit` for visual consistency with mobile.

### 6.6 — Phase 6 Verification

**Manual tests**:
1. Open in Chrome → Verify "Install" icon in address bar
2. Install as PWA → Verify it opens as standalone app
3. Verify offline: disconnect internet → the app should show cached content
4. Verify web push notifications
5. Verify on mobile browsers (Chrome Android, Safari iOS)

**Lighthouse audit**:
```bash
# In Chrome DevTools → Lighthouse → Progressive Web App
# Target: Score > 90
```

---

## New Files by Phase

### Phase 1 (6 new files, 11 modified files)

| Action | File |
|--------|------|
| **Create** | `lib/shared/platform/io_stub.dart` |
| **Create** | `lib/background/web_background_service.dart` |
| **Create** | `lib/shared/utils/biometrics_helper_web.dart` |
| **Create** | `lib/shared/utils/biometrics_helper_stub.dart` |
| **Create** | `lib/shared/utils/notification_permission_helper_web.dart` |
| **Create** | `lib/shared/utils/notification_permission_helper_stub.dart` |
| **Modify** | 11 files — add conditional import of `dart:io` (1 line each) |
| **Modify** | `lib/background/background_service.dart` — WebBackgroundService instead of throw |
| **Modify** | `lib/main.dart` — conditional imports for biometrics and notification helper |

### Phase 2 (4 new files, 1 modified file)

| Action | File |
|--------|------|
| **Create** | `lib/shared/providers/database_factory.dart` |
| **Create** | `lib/shared/providers/database_factory_stub.dart` |
| **Create** | `lib/shared/providers/database_factory_mobile.dart` |
| **Create** | `lib/shared/providers/database_factory_web.dart` |
| **Modify** | `lib/shared/providers/mostro_database_provider.dart` — use factory |

### Phase 3 (1-2 new files, 1-2 modified files)

| Action | File |
|--------|------|
| **Create** | `lib/shared/platform/websocket_helper.dart` |
| **Modify** | `lib/features/relays/relays_notifier.dart` — use websocket_helper |
| **Modify** | `pubspec.yaml` — add `web_socket_channel` |

### Phase 4 (3-4 new files, 2-3 modified files)

| Action | File |
|--------|------|
| **Create** | `lib/services/logger_export_service_web.dart` |
| **Create** | `lib/services/logger_export_service_stub.dart` |
| **Modify** | `lib/services/lifecycle_manager.dart` — add kIsWeb guard |
| **Modify** | `lib/services/deep_link_service.dart` — add kIsWeb guard |
| **Possible** | Firebase web configuration files |

### Phase 5 (6-8 new files, 3-4 modified files)

| Action | File |
|--------|------|
| **Create** | `lib/services/file_data.dart` |
| **Create** | `lib/features/chat/widgets/file_operations.dart` |
| **Create** | `lib/features/chat/widgets/file_operations_web.dart` |
| **Create** | `lib/features/chat/widgets/file_operations_mobile.dart` |
| **Create** | `lib/features/chat/widgets/file_operations_stub.dart` |
| **Modify** | `lib/features/chat/widgets/encrypted_file_message.dart` |
| **Modify** | `lib/features/chat/widgets/encrypted_image_message.dart` |
| **Modify** | `lib/services/encrypted_file_upload_service.dart` |

### Phase 6 (1-2 new files, 2-3 modified files)

| Action | File |
|--------|------|
| **Possible** | `web/firebase-messaging-sw.js` |
| **Modify** | `web/manifest.json` |
| **Modify** | `web/index.html` |

### Estimated totals
- **~22-28 new files**
- **~20-25 modified files**
- **0 mobile files deleted or rewritten**

---

## Risks and Pending Decisions

### High Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **`dart_nostr` web support** | Confirmed: `dart_nostr` does NOT compile for web due to 3 unused `dart:io` imports in `registry.dart`, `relays.dart`, and `relay.dart`. The actual WebSocket implementation already uses `web_socket_channel` (cross-platform), so the networking code works — only the dead imports break compilation. | Minimal fix: remove 3 unused imports. Options: (1) Submit PR to `anasfik/nostr`, (2) temporary fork, (3) local path dependency override. |
| **Key security on web** | `flutter_secure_storage` uses `localStorage` on web, which is visible in DevTools. For a P2P trading app, this is a security risk. | Phase 2: Document limitation. Future: Implement Web Crypto API + encrypted IndexedDB. |
| **Web performance** | Flutter web with CanvasKit can be heavy (~2MB initial load). For emerging markets with slow connections, this is a problem. | Evaluate HTML renderer. Implement lazy loading. Optimize assets. |

### Medium Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **`open_file` replacement** | No direct equivalent on web. Files are downloaded, not "opened". | Different UX is acceptable: "Download" button instead of "Open". |
| **Background processing** | Web has no real background services. WebSocket connections pause when the tab is inactive. | Accept limitation. Reconnect when returning to tab. Service Worker for push notifications. |
| **Firebase web config** | If the project doesn't have Firebase configured for web, additional setup in Firebase Console is required. | Verify in Phase 4. If missing, configure or use Web Notifications API directly. |

### Low Risk

| Risk | Description | Mitigation |
|------|-------------|------------|
| **Deep links** | On web they are simply URLs. `app_links` doesn't apply. | GoRouter already handles URL routing. Only needs app_links skip. |
| **Biometrics** | Don't exist on web. | Return true (skip auth) or use PIN as alternative. |
| **Permissions** | Web has its own permissions model. | `permission_handler` no-op on web. Use browser Notification API when needed. |

### Pending Decisions

1. **Which web renderer?** — CanvasKit (faithful to mobile) vs HTML (lighter)
2. **What to do with key storage on web?** — localStorage acceptable for MVP, or implement Web Crypto API from the start
3. **Firebase or native Web Push?** — Firebase gives cross-platform FCM, Web Push is simpler
4. **`dart_nostr` web fix strategy** — Confirmed blocker (3 dead `dart:io` imports). Choose: upstream PR, temporary fork, or path override
5. **PIN as biometrics alternative on web?** — UX decision
6. **Hosting?** — GitHub Pages, Vercel, Cloudflare Pages, self-hosted

---

## Recommended Execution Order

```text
Phase 1 ──→ Phase 2 ──→ Phase 3 ──→ Phase 4 ──→ Phase 5 ──→ Phase 6
 3-5 days    2-3 days    3-5 days    3-4 days    4-5 days    3-5 days

 Compiles    DB works    Nostr works  Services    Chat files   Full PWA
 on web      on web      on web       no-crash    work         installable
```

**Total estimate**: 18-27 development days (1 developer)

**Critical milestone**: After Phase 3, the app is functional on web for the core flow (view orders, create/take orders, text chat). Phases 4-6 are incremental improvements.

---

## Notes on `dart:html` Deprecation

Since Dart 3.x, `dart:html` has been replaced by the `package:web` package. This project uses **Dart 3.9.2**, so all web implementations **must** use:

```dart
import 'package:web/web.dart' as web;
```

instead of the deprecated:

```dart
import 'dart:html' as html;  // DO NOT USE
```

Similarly, conditional imports **must** use `dart.library.js_interop` instead of the legacy `dart.library.html`:

```dart
// Correct (Dart 3.x+)
if (dart.library.js_interop) 'web_impl.dart'

// Deprecated — do NOT use
if (dart.library.html) 'web_impl.dart'
```

All code examples in this plan already use the modern APIs.
