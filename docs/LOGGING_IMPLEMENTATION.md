# In-App Logging System Implementation

## Overview

Implementation of a comprehensive logging system for MostroP2P mobile app with in-memory capture, background isolate support, privacy sanitization, and export capabilities.

## Design Approach

### Why This Architecture?

This implementation uses a **singleton logger pattern with centralized output management** rather than individual logger instances per service. While this approach requires updating all logging calls across the codebase, it provides critical advantages:

**1. Guaranteed Log Capture**
- Single source of truth ensures NO logs are missed
- All application logs automatically captured in memory
- Background isolates seamlessly integrated via SendPort

**2. Consistent Privacy Protection**
- Centralized sanitization means sensitive data CANNOT leak
- Single `cleanMessage()` function applies to all logs uniformly
- No risk of individual services bypassing sanitization

**3. Memory Safety**
- Centralized buffer with strict size limits prevents OOM issues
- Batch deletion strategy maintains performance
- Predictable memory footprint regardless of log volume

**4. Development Experience**
- Simple API: `logger.i()`, `logger.e()`, `logger.d()`
- No configuration needed per service
- Stack trace extraction for debugging
- It keeps normal console logs and minimize logs for UI

### Trade-offs

**Cons of Singleton Approach**:
- Requires updating ~30+ files to replace `print()` calls
- One-time migration effort across codebase

## Architecture

```
Main Isolate:
  logger (singleton) → MemoryLogOutput → UI (LogsScreen)
                    ↘ ConsoleOutput

Background Isolate:
  logger → IsolateLogOutput → SendPort → Main Isolate ReceivePort → MemoryLogOutput
```

## Critical Implementation Details

### 1. Logger Usage Pattern

**IMPORTANT**: Always use the singleton `logger` instance, never instantiate `Logger()` directly.

```dart
//  CORRECT
import 'package:mostro_mobile/services/logger_service.dart';

logger.i('Info message');
logger.e('Error occurred', error: e, stackTrace: stack);

//  WRONG - Do not instantiate directly
final myLogger = Logger();
```

### 2. Configuration (`lib/core/config.dart`)


```dart
// Logger configuration
static const int logMaxEntries = 1000;        // Maximum logs in memory
static const int logBatchDeleteSize = 100;    // Batch delete when limit exceeded
static bool fullLogsInfo = true;              // true = PrettyPrinter, false = SimplePrinter
```

**Buffer Management**:
- When buffer exceeds `logMaxEntries`, oldest `logBatchDeleteSize` entries are deleted
- FIFO queue ensures recent logs are preserved
- Prevents memory exhaustion from log flooding

### 3. Background Isolate Integration

Background services MUST initialize logging with `IsolateLogOutput`:

```dart
@pragma('vm:entry-point')
void backgroundServiceEntryPoint(SendPort sendPort) async {
  // Get log sender from main isolate
  final logSender = isolateLogSenderPort;

  // Initialize logger for this isolate
  Logger.level = Level.debug;
  final logger = Logger(
    printer: SimplePrinter(),
    output: IsolateLogOutput(logSender),
  );

  // Now logs from this isolate appear in main app
  logger.i('Background service started');
}
```

**Main isolate setup** (in `main.dart`):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize log receiver BEFORE starting background services
  initIsolateLogReceiver();

  // ... rest of initialization
}
```

### 4. Privacy Sanitization

The `cleanMessage()` function automatically redacts:

| Pattern | Replacement | Example |
|---------|-------------|---------|
| `nsec[0-9a-z]+` | `[PRIVATE_KEY]` | `nsec1abc...` → `[PRIVATE_KEY]` |
| `"privateKey":"..."` | `"privateKey":"[REDACTED]"` | JSON field redacted |
| `"mnemonic":"..."` | `"mnemonic":"[REDACTED]"` | Seed phrase redacted |
| ANSI codes | Removed | Color/formatting stripped |
| Emojis | Removed | All emoji ranges |

### 5. File Storage & Permissions

**Android/iOS**:
```dart
// External storage (requires permissions in future)
final directory = await getExternalStorageDirectory();
final logsDir = Directory('${directory.path}/MostroLogs');
```

**PERMISSIONS REQUIRED** (not yet implemented):
- Android: `WRITE_EXTERNAL_STORAGE` permission
- iOS: Automatic with app sandbox

**Desktop/Web**:
```dart
// Application documents (no special permissions)
final directory = await getApplicationDocumentsDirectory();
```

**Storage location display**:
- UI shows storage path to user
- Configurable via `Settings.customLogStorageDirectory`

## Migration Example

### Service Integration

```dart
// lib/services/nostr_service.dart

import 'package:mostro_mobile/services/logger_service.dart';

class NostrService {
  Future<void> connect() async {
    logger.i('Connecting to Nostr relays');

    try {
      await _connectToRelays();
      logger.i('Successfully connected to ${relays.length} relays');
    } catch (e, stack) {
      logger.e('Failed to connect to relays', error: e, stackTrace: stack);
      rethrow;
    }
  }
}
```

### Background Service

```dart
// lib/background/mobile_background_service.dart

@pragma('vm:entry-point')
void backgroundMain(SendPort sendPort) async {
  final logSender = isolateLogSenderPort;
  final logger = Logger(
    printer: SimplePrinter(),
    output: IsolateLogOutput(logSender),
  );

  logger.i('Background service started');

  try {
    await performBackgroundTask();
  } catch (e, stack) {
    logger.e('Background task failed', error: e, stackTrace: stack);
  }
}
```


---

**Version**: 1.0
**Status**: Phase 1 - Planning Complete
