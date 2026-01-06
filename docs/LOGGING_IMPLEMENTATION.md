# In-App Logging System Implementation

## Overview

Comprehensive logging system for MostroP2P mobile app with in-memory capture, background isolate support and export capabilities. Implemented across 4 phases.

## Design Approach

### Architecture Decision

This implementation uses a singleton logger pattern with centralized output management rather than individual logger instances per service.

**Key Benefits**:
- Single source of truth ensures complete log capture
- Centralized sanitization prevents sensitive data leaks
- Memory safety through strict buffer management
- Consistent behavior across main and background isolates

**Trade-off**:
- Requires migration of all logging calls across codebase to use shared logger instance

## System Architecture

```
Main Isolate:
  logger (singleton) → _MultiOutput → MemoryLogOutput → UI (LogsScreen)
                                   → ConsoleOutput (debug only)

Background Isolate:
  logger → IsolateLogOutput → SendPort → ReceivePort → addLogFromIsolate() → MemoryLogOutput
```

## Implementation Phases

### Phase 1: Core UI and Functionality (Completed)

**Scope**:
- Basic in-app logging UI with enable/disable toggle
- Log filtering by level (All, Errors, Warnings, Info, Debug)
- Search functionality with real-time filtering
- Share functionality via system share dialog
- Multi-language support (EN, ES, IT)
- Background isolate logging support
- Memory-based log storage with rotation

**Status**: Complete - Branch `feat/br/logging-screen`

### Phase 2: Folder Picker and Storage Permissions (Pending)

**Scope**:
- Custom folder picker for Android/iOS
- Storage permissions handling
- Save to device functionality
- Configurable storage location
- Permission request flow with user education

**Implementation Requirements**:
- Add `permission_handler` package
- Implement folder picker UI
- Add storage permission request dialog
- Enable "Save File" button in logs screen
- Store user-selected path in settings
- Handle permission denial gracefully

**Status**: Not started

### Phase 3: Recording Indicator (Pending)

**Scope**:
- Minimalist recording indicator widget
- Shows when log capture is active
- Non-intrusive UI element
- Persistent across app navigation
- Quick access to logs screen

**Implementation Requirements**:
- Create component
- Add to main app scaffold overlay
- Show only when `MemoryLogOutput.isLoggingEnabled` is true
- Tap indicator to navigate to logs screen

### Phase 4: Full migration (Pending)

**Scope**:
- Remplace Logger() local instances for logger_service

**Implementation Requirements**:
- Modify over 30 files


**Status**: Not started

## Critical Implementation Details

### 1. Logger Usage Pattern

Always use the singleton logger instance, never instantiate Logger() directly.

```dart
// Correct
import 'package:mostro_mobile/services/logger_service.dart';

logger.i('Info message');
logger.e('Error occurred', error: e, stackTrace: stack);

// Wrong - Do not instantiate directly
final myLogger = Logger();
```

### 2. Configuration

Location: `lib/core/config.dart`

```dart
static const int logMaxEntries = 1000;
static const int logBatchDeleteSize = 100;
```

**Buffer Management**:
- When buffer exceeds logMaxEntries, oldest logBatchDeleteSize entries are deleted
- FIFO queue ensures recent logs are preserved
- Prevents memory exhaustion from log flooding

### 3. Debug vs Release Behavior

**Debug Mode**:
- Full console logging always enabled
- UI capture only when user enables logging switch
- PrettyPrinter with colors and stack traces

**Release Mode**:
- No console logging (null ConsoleOutput)
- UI capture only when user enables logging switch
- Higher log level threshold (warning vs debug)

Implementation in `_ProductionOptimizedFilter`:
```dart
bool shouldLog(LogEvent event) {
  // Debug: always log to console
  if (Config.isDebug) {
    return true;
  }
  // Release: only if UI switch is enabled (console is null anyway)
  return MemoryLogOutput.isLoggingEnabled;
}
```

## Migration Guide

### Service Integration Example

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

### Background Service Example

```dart
// lib/background/mobile_background_service.dart

import 'package:mostro_mobile/services/logger_service.dart' as logger_service;

@pragma('vm:entry-point')
void backgroundMain(SendPort sendPort) async {
  final logSender = logger_service.isolateLogSenderPort;

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

**Version**: 2.0
**Status**: Phase 1 Complete | Phase 2-3 Pending
**Last Updated**: 2026-01-05
