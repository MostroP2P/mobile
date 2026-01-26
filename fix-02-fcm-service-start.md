# Fix 02: FCM Handler Should Start the Service

## The Problem

When a push notification arrives via FCM and the background service is not running, the current code only saves a flag but **never starts the service**:

```dart
if (!isRunning) {
  await sharedPrefs.setBool('fcm.pending_fetch', true);  // Just saves a flag!
  // Service is NOT started - notification is lost
}
```

This means:
1. FCM wakes up the app
2. Handler checks if service is running
3. Service is dead → saves a flag
4. Handler exits
5. App goes back to sleep
6. User never gets notification
7. Flag is only checked when user manually opens app

## Current Flow (Broken)

```
FCM Push arrives
       ↓
firebaseMessagingBackgroundHandler() called
       ↓
Check: is background service running?
       ↓
NO → Save 'pending_fetch' flag → Exit
       ↓
Nothing happens until user opens app
       ↓
❌ Notification lost
```

## Desired Flow

```
FCM Push arrives
       ↓
firebaseMessagingBackgroundHandler() called
       ↓
Check: is background service running?
       ↓
NO → Start the background service
       ↓
Service starts → Connects to relays → Fetches events
       ↓
Show local notification
       ↓
✅ User sees notification
```

## Why This is Tricky

The FCM background handler runs in a **separate isolate** with limitations:
- No access to Flutter engine (not fully initialized)
- No access to Riverpod providers
- Limited plugin availability
- Must complete quickly (Android kills long-running handlers)

Starting a Flutter background service from the FCM handler requires careful handling.

## Implementation Options

### Option A: Direct Service Start from FCM Handler

Start the FlutterBackgroundService directly from the FCM handler.

**Pros:**
- Direct and simple
- Immediate service start

**Cons:**
- May have plugin initialization issues
- Need to handle service configuration in handler
- Potential race conditions

### Option B: Use WorkManager as Intermediate

FCM handler schedules a WorkManager task, which then starts the background service.

**Pros:**
- WorkManager handles all the complexity
- More reliable across Android versions
- Better integration with Android's job scheduler

**Cons:**
- Additional dependency
- Slight delay (WorkManager scheduling)
- More moving parts

### Option C: Hybrid Approach

1. FCM handler tries to start service directly
2. If that fails, schedules WorkManager task as fallback
3. WorkManager task starts service

**Pros:**
- Fast path when possible
- Fallback for edge cases
- Maximum reliability

**Cons:**
- Most complex implementation
- More code to maintain

## Recommendation

**Option A** first, with proper error handling. Reasons:
1. `flutter_background_service` is designed to be started from FCM handlers
2. Simpler implementation
3. Can add WorkManager fallback later if needed

## Key Implementation Details

### 1. Service Configuration Must Be Available

The FCM handler needs access to the same service configuration used by the main app. This means:
- Store settings in SharedPreferences (already done)
- Load settings in FCM handler
- Pass to service on start

### 2. Avoid Duplicate Starts

Need to handle the case where:
- FCM handler starts service
- App comes to foreground
- LifecycleManager also tries to manage service

Solution: Use proper state checking and synchronization.

### 3. Handler Must Complete Quickly

Android kills FCM handlers that take too long. The handler should:
1. Start the service (fire and forget)
2. Exit immediately
3. Let the service handle the actual work

### 4. Handle Service Already Starting

Race condition: Multiple FCM messages arrive, each trying to start service.

Solution: Check `isRunning` and handle "already starting" state.

## What Changes

1. `fcm_service.dart` - Start service instead of just saving flag
2. Possibly `mobile_background_service.dart` - Expose method to start from external context
3. May need to restructure service initialization

## Testing Scenarios

1. App killed → FCM arrives → Service should start → Notification shown
2. App in background, service dead → FCM arrives → Service restarts
3. Multiple FCM messages in quick succession → Only one service start
4. FCM arrives while service is starting → No duplicate start
5. FCM arrives, service starts, app opened → Clean transition to foreground

## Related Issues

- Works best with Fix 01 (Foreground Service) - once started, service stays alive
- Fix 04 (Subscription Persistence) ensures restarted service knows what to subscribe to
