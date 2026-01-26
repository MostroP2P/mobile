# Fix 06: Initialization Race Condition

## The Problem

There's a race condition in how the background service is initialized:

```dart
// mobile_background_service.dart

@override
Future<void> init() async {
  await service.configure(...);  // 1. Configure service

  service.on('on-start').listen((data) {  // 2. THEN set up listener
    _isRunning = true;
    service.invoke('start', {...});
  });
}
```

The problem: If the service emits `on-start` between steps 1 and 2, the event is lost.

## Why This Happens

`flutter_background_service` starts asynchronously. The timing is:

```
configure() called
       ↓
Service begins starting in background
       ↓
[Race condition window]
       ↓
Listener set up
       ↓
Maybe receives on-start, maybe not
```

On faster devices, the service might start and emit `on-start` before the listener is registered.

## Symptoms

- Service appears to not start
- `_isRunning` stays false
- `_serviceReady` stays false
- All operations queue in `_pendingOperations` forever
- Background notifications never work

This is intermittent - works on some devices/runs, fails on others.

## Current Mitigation

There's a partial mitigation:

```dart
service.on('on-start').listen((data) {
  _isRunning = true;
  service.invoke('start', {...});  // Sends settings to service
});
```

And in `_startService()`:

```dart
// Wait for service to be running
while (!(await service.isRunning())) {
  await Future.delayed(const Duration(milliseconds: 50));
}

// Then also invoke start
service.invoke('start', {...});
```

This sends `start` twice sometimes, but at least the service gets initialized.

However, `_isRunning` and `_serviceReady` flags may still be wrong.

## Implementation Options

### Option A: Set Up Listeners Before Configure

```dart
@override
Future<void> init() async {
  // Set up listeners FIRST
  service.on('on-start').listen(...);
  service.on('service-ready').listen(...);

  // THEN configure
  await service.configure(...);
}
```

**Pros:**
- Simple fix
- Listeners ready when events fire

**Cons:**
- Listeners might fire before configure completes (different race)
- May not be supported by the library

### Option B: Don't Rely on Events for State

Use polling instead of events:

```dart
Future<void> _startService() async {
  await service.startService();

  // Poll until running
  while (!(await service.isRunning())) {
    await Future.delayed(const Duration(milliseconds: 50));
  }

  _isRunning = true;  // Set based on poll, not event

  // Send settings
  service.invoke('start', {...});

  // Poll until ready (or use timeout)
  await _waitForReady();
}
```

**Pros:**
- Deterministic
- No event timing issues

**Cons:**
- Polling is less efficient
- Need to define "ready" state clearly

### Option C: State Machine Approach

Implement a proper state machine:

```
States: NOT_RUNNING → STARTING → RUNNING → READY
```

Transitions based on:
- `startService()` call: NOT_RUNNING → STARTING
- `isRunning()` returns true: STARTING → RUNNING
- Settings acknowledged: RUNNING → READY

**Pros:**
- Clear state management
- Handles all edge cases
- Easy to debug

**Cons:**
- More code
- Might be overkill

### Option D: Retry Pattern

If initial setup seems to fail, retry:

```dart
Future<void> _ensureServiceReady() async {
  const maxAttempts = 3;

  for (var attempt = 0; attempt < maxAttempts; attempt++) {
    if (await _tryInitialize()) {
      return; // Success
    }
    await Future.delayed(Duration(seconds: 1 * (attempt + 1)));
  }

  throw StateError('Failed to initialize service');
}
```

**Pros:**
- Handles transient failures
- Simple to understand

**Cons:**
- Slower when retries needed
- Doesn't fix root cause

## Recommendation

**Option B** with elements of C:

1. Set up listeners before configure (can't hurt)
2. Use polling for definitive state (`isRunning()`)
3. Don't trust `_isRunning` flag alone
4. Add timeout for safety

## The Ready State Problem

There's also ambiguity about what "ready" means:

Current flow:
```
Service running → invoke('start') → Service receives settings → invoke('service-ready')
```

Problems:
- What if `invoke('start')` fails silently?
- What if service crashes during init?
- What if settings are invalid?

Solution: Add acknowledgment protocol:
```
invoke('start', {id: 'init_123', ...})
       ↓
Service processes settings
       ↓
invoke('service-ready', {id: 'init_123', success: true})
```

Match IDs to ensure we're getting the right acknowledgment.

## What Changes

1. `mobile_background_service.dart`:
   - Reorder listener setup
   - Use polling for state
   - Add timeout handling
   - Consider state machine

2. `background.dart`:
   - Add acknowledgment with ID
   - Handle initialization errors

## Testing

1. Rapid start/stop cycles
2. Start on slow device
3. Start on fast device
4. Start during heavy system load
5. Verify `_isRunning` and `_serviceReady` are correct

## Logging

Add detailed logging:
- When listeners are set up
- When configure completes
- When events are received
- State transitions

This helps debug timing issues in the field.

## Related Issues

- This affects Fix 02 (FCM Service Start) - FCM starts service, must be reliable
- This affects Fix 04 (Subscription Persistence) - must restore after reliable start
