# Logging System Architecture

## Overview

Mostro Mobile uses a centralized singleton logger pattern with in-memory capture, background isolate support, privacy sanitization, and export capabilities. All application logging goes through a single `logger` instance from `lib/services/logger_service.dart`.

## Why a Singleton

A centralized logger provides:
- **Guaranteed capture**: single source of truth, no logs missed
- **Consistent privacy**: centralized `cleanMessage()` sanitization for all logs — sensitive data cannot leak through individual services
- **Memory safety**: centralized buffer with strict size limits prevents OOM
- **Simple API**: `logger.i()`, `logger.e()`, `logger.d()` — no per-service configuration

Trade-off: required migrating ~30+ files from `print()` calls (one-time effort, completed).

## Architecture

```text
Main Isolate:
  logger (singleton) → MemoryLogOutput → UI (LogsScreen)
                     ↘ ConsoleOutput

Background Isolate:
  logger → IsolateLogOutput → SendPort → Main Isolate ReceivePort → MemoryLogOutput
```

## Usage

```dart
// CORRECT — always use the singleton
import 'package:mostro_mobile/services/logger_service.dart';

logger.i('Info message');
logger.e('Error occurred', error: e, stackTrace: stack);

// WRONG — never instantiate directly
final myLogger = Logger();
```

## Configuration (`lib/core/config.dart`)

```dart
static const int logMaxEntries = 1000;       // Maximum logs in memory
static const int logBatchDeleteSize = 100;   // Batch delete when limit exceeded
static bool fullLogsInfo = true;             // true = PrettyPrinter, false = SimplePrinter
```

Buffer uses FIFO: when exceeding `logMaxEntries`, the oldest `logBatchDeleteSize` entries are removed.

## Background Isolate Integration

Background services initialize logging with `IsolateLogOutput`:

```dart
@pragma('vm:entry-point')
void backgroundServiceEntryPoint(SendPort sendPort) async {
  final logSender = isolateLogSenderPort;
  Logger.level = Level.debug;
  final logger = Logger(
    printer: SimplePrinter(),
    output: IsolateLogOutput(logSender),
  );
  logger.i('Background service started');
}
```

Main isolate setup (in `main.dart`):
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  initIsolateLogReceiver(); // BEFORE starting background services
  // ...
}
```

## UI Components

- **Logging toggle** in Settings (Dev Tools section) — resets to OFF on every app restart
- **LogsScreen** — filterable log viewer
- **Recording indicator** — floating red dot (bottom-left) when logging is enabled, tappable to navigate to logs
- **Export** — save to file via FilePicker or share via system share sheet
- **Clear** — with confirmation dialog

## Key Files

| File | Purpose |
|------|---------|
| `lib/services/logger_service.dart` | Singleton logger, MemoryLogOutput, sanitization |
| `lib/core/config.dart` | Buffer size configuration |
| `lib/features/settings/` | Logging toggle UI |

## References

- [Mostro Protocol](https://mostro.network/protocol/) — for understanding the events being logged
