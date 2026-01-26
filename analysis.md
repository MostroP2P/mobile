# Background Notifications Analysis - Android

## Overview

Analysis of inconsistent background notification behavior across Android devices. Some devices work correctly, others don't receive notifications even with all permissions granted and without killing the app.

---

## Critical Problems

### 1. Service NOT running as Foreground Service

**Location**: `lib/background/mobile_background_service.dart:33`

```dart
isForegroundMode: false,
```

**Impact**: Android 8+ aggressively kills background services. A foreground service with a persistent notification has high priority and is not easily killed.

**Solution**: Set `isForegroundMode: true` and provide a proper notification.

---

### 2. FCM Handler does NOT start the service

**Location**: `lib/services/fcm_service.dart:49-51`

```dart
if (!isRunning) {
  await sharedPrefs.setBool('fcm.pending_fetch', true);  // Only saves flag!
}
```

**Impact**: When a push arrives and the service is dead, it only saves a flag but **never starts the service**. The user never receives the notification.

**Solution**: Start the background service from the FCM handler when it's not running.

---

### 3. Missing permissions in AndroidManifest

**Location**: `android/app/src/main/AndroidManifest.xml`

```xml
<!-- These critical permissions are missing: -->
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

**Impact**:
- Without `WAKE_LOCK`, CPU can sleep and WebSocket connections are lost
- Without `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, manufacturers can kill the app aggressively
- Without `RECEIVE_BOOT_COMPLETED`, service doesn't restart after device reboot

---

### 4. No subscription persistence

**Location**: `lib/background/background.dart:23`

```dart
final Map<String, Map<String, dynamic>> activeSubscriptions = {};  // In memory only!
```

**Impact**: If the service is killed and restarted, `activeSubscriptions` is empty and no events are received.

**Solution**: Persist subscriptions to SharedPreferences or database, restore on service start.

---

## Secondary Problems

### 5. No heartbeat/keep-alive mechanism

WebSocket connections can be silently closed by:
- Android Doze mode
- NAT timeouts from carriers/routers
- Battery optimization from manufacturers (Xiaomi, Samsung, Huawei)

There's no periodic ping to detect dead connections.

**Solution**: Implement periodic ping/pong or use WorkManager for periodic wake-ups.

---

### 6. Race condition in initialization

**Location**: `lib/background/mobile_background_service.dart:42-51`

```dart
service.on('on-start').listen((data) {  // Configured AFTER configure()
  _isRunning = true;
  service.invoke('start', ...);
});
```

**Impact**: If the service starts before the listener is configured, the event is lost.

**Solution**: Configure listeners before calling `configure()` or use a more robust initialization pattern.

---

### 7. No robust retry on transitions

**Location**: `lib/services/lifecycle_manager.dart:59`

```dart
await Future.delayed(const Duration(milliseconds: 500));  // Hardcoded, may not be enough
```

**Impact**: On slower devices, 500ms may not be sufficient for the service to fully transition.

**Solution**: Use exponential backoff or wait for explicit ready signal.

---

## OEM-Specific Issues

| Manufacturer | Behavior | Required User Action |
|--------------|----------|---------------------|
| **Xiaomi** | MIUI kills apps aggressively | Enable "Autostart", disable "Battery Saver" for app |
| **Samsung** | "Sleeping apps" and "Deep sleeping apps" kill background services | Remove from sleeping apps list |
| **Huawei** | EMUI has its own very aggressive battery management | Add to "Protected apps" |
| **OnePlus** | OxygenOS "Battery Optimization" kills apps | Disable battery optimization for app |
| **Oppo/Vivo** | ColorOS/FuntouchOS require special autostart permissions | Enable autostart permission |

---

## Current Architecture Flow (Problematic)

```
┌─────────────────────────────────────────────────────────────┐
│ CURRENT FLOW                                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  App Background → Start service → WebSocket → Events        │
│                         ↓                                   │
│              [Android kills service]                        │
│                         ↓                                   │
│              ❌ No reconnection                             │
│              ❌ Subscriptions lost                          │
│              ❌ Notifications don't arrive                  │
│                                                             │
│  FCM Push → Handler → Service running? → NO                 │
│                         ↓                                   │
│              Only saves flag ❌ Doesn't start service       │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## Proposed Solutions (Priority Order)

### Priority 1 - Critical
1. Enable foreground service mode with persistent notification
2. Make FCM handler start the background service when not running
3. Add missing Android permissions

### Priority 2 - High
4. Persist subscriptions to storage
5. Restore subscriptions on service restart
6. Fix race condition in initialization

### Priority 3 - Medium
7. Implement heartbeat/keep-alive for WebSocket connections
8. Add OEM-specific guidance in app settings
9. Implement WorkManager as fallback for periodic sync

---

## Files to Modify

| File | Changes |
|------|---------|
| `lib/background/mobile_background_service.dart` | Enable foreground mode, fix initialization |
| `lib/services/fcm_service.dart` | Start service from handler |
| `lib/background/background.dart` | Add subscription persistence/restoration |
| `android/app/src/main/AndroidManifest.xml` | Add missing permissions |
| `lib/services/lifecycle_manager.dart` | Improve transition handling |

---

## Testing Checklist

- [ ] Test with app in background for extended periods (1h+)
- [ ] Test after device reboot
- [ ] Test with Doze mode active
- [ ] Test on Xiaomi device with MIUI
- [ ] Test on Samsung device with One UI
- [ ] Test with battery saver enabled
- [ ] Test FCM wake-up when service is dead
- [ ] Verify notifications arrive consistently

---

*Last updated: January 2026*
