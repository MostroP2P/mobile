# Background Notifications Fix - Hybrid Approach

## Overview

This document describes the hybrid approach to fix inconsistent background notification behavior on Android devices. The solution combines a **smart foreground service** (only when needed) with **reactive wake-up via FCM**.

## Problem Summary

Android aggressively kills background services since Android 8 (Oreo). The current implementation uses `isForegroundMode: false`, which means:

- Service can be killed at any time
- WebSocket connections are lost
- Notifications don't arrive
- Behavior varies by device and manufacturer

A previous attempt with always-on foreground service (`isForegroundMode: true`) was reverted because the persistent notification was annoying to users.

## Hybrid Solution

Combine the best of both worlds:

```
┌─────────────────────────────────────────────────────────────┐
│                    HYBRID APPROACH                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  NO ACTIVE TRADES                                           │
│  ├─ Background mode (no notification)                       │
│  ├─ Service may be killed by Android                        │
│  └─ FCM push can revive it when needed                      │
│                                                             │
│  WITH ACTIVE TRADES                                         │
│  ├─ Foreground service (persistent notification)            │
│  ├─ Service is protected, won't be killed                   │
│  ├─ WebSocket stays connected                               │
│  └─ Notifications arrive reliably                           │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Why This Works

1. **No notification when browsing** - Users exploring the order book don't see a persistent notification
2. **Notification when relevant** - Active trade = notification makes sense, user understands why it's there
3. **FCM as safety net** - Even if service dies with no active trades, FCM can wake it up
4. **Maximum reliability when it matters** - During active trades, service is fully protected

## Implementation Components

### Component 1: Smart Foreground Service

**Location**: `lib/background/mobile_background_service.dart`

Logic:
- Monitor active trades count
- `activeTrades > 0` → Switch to foreground mode
- `activeTrades == 0` → Switch to background mode

Notification content when active:
```
┌─────────────────────────────────┐
│ 🔔 Mostro                       │
│ Monitoring X active trade(s)    │
└─────────────────────────────────┘
```

### Component 2: FCM Service Wake-up (Fix 02)

**Location**: `lib/services/fcm_service.dart`

Current behavior:
```dart
if (!isRunning) {
  await sharedPrefs.setBool('fcm.pending_fetch', true);  // Only saves flag!
}
```

New behavior:
```dart
if (!isRunning) {
  await MobileBackgroundService.instance.startService();  // Actually start it!
  await sharedPrefs.setBool('fcm.pending_fetch', true);
}
```

### Component 3: Android Permissions (Fix 03)

**Location**: `android/app/src/main/AndroidManifest.xml`

Add missing permissions:
```xml
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

### Component 4: Subscription Persistence (Fix 04)

**Location**: `lib/background/background.dart`

Current behavior:
```dart
final Map<String, Map<String, dynamic>> activeSubscriptions = {};  // Lost on restart!
```

New behavior:
- Save subscriptions to SharedPreferences/Sembast on creation
- Restore subscriptions when service starts
- Clean up subscriptions when trades complete

## Flow Diagrams

### Scenario 1: User with Active Trade

```
User takes an order
       ↓
Trade becomes active
       ↓
Service switches to foreground mode
       ↓
Notification appears: "Monitoring 1 active trade"
       ↓
WebSocket protected, events arrive
       ↓
Trade completes
       ↓
Service switches to background mode
       ↓
Notification disappears
```

### Scenario 2: Push While Service is Dead

```
Service killed by Android (no active trades)
       ↓
FCM push arrives from Mostro
       ↓
FCM handler starts the service
       ↓
Service restores subscriptions from storage
       ↓
Processes pending events
       ↓
Shows notification to user
```

### Scenario 3: Device Reboot

```
Device reboots
       ↓
RECEIVE_BOOT_COMPLETED triggers service start
       ↓
Service restores subscriptions
       ↓
Checks for active trades
       ↓
Active trades? → Foreground mode
No trades? → Background mode (FCM will wake if needed)
```

## Notification Channel Configuration

```dart
NotificationChannel(
  channelKey: 'mostro_background_service',
  channelName: 'Trade Monitoring',
  channelDescription: 'Keeps Mostro connected during active trades',
  importance: NotificationImportance.Low,  // No sound, minimal visual
  playSound: false,
  enableVibration: false,
)
```

Users can customize or hide this channel in Android settings.

## Files to Modify

| File | Changes |
|------|---------|
| `lib/background/mobile_background_service.dart` | Smart foreground/background switching |
| `lib/background/background.dart` | Subscription persistence, trade count monitoring |
| `lib/services/fcm_service.dart` | Start service from FCM handler |
| `android/app/src/main/AndroidManifest.xml` | Add WAKE_LOCK, BOOT_COMPLETED permissions |
| `lib/features/trades/providers/` | Notify background service of trade count changes |

## Implementation Order

1. **Fix 03**: Add Android permissions (low risk, immediate benefit) ✅ **COMPLETED**
2. **Fix 02**: FCM starts service (enables reactive wake-up)
3. **Fix 04**: Subscription persistence (service can recover state)
4. **Fix 01**: Smart foreground service (ties it all together)

## Testing Checklist

- [ ] No notification when browsing order book (no active trades)
- [ ] Notification appears when trade becomes active
- [ ] Notification shows correct trade count
- [ ] Notification disappears when all trades complete
- [ ] Service survives extended background time during active trade
- [ ] FCM wakes up dead service
- [ ] Subscriptions restored after service restart
- [ ] Works after device reboot
- [ ] Test on Xiaomi/Samsung/Huawei devices

## OEM-Specific Considerations

Some manufacturers require additional user action:

| Manufacturer | Action Required |
|--------------|-----------------|
| Xiaomi | Enable "Autostart" in settings |
| Samsung | Remove from "Sleeping apps" |
| Huawei | Add to "Protected apps" |
| OnePlus | Disable battery optimization |

Consider adding a help screen in settings explaining these steps for affected users.

## Rollback Plan

If issues arise:
1. Disable smart foreground switching (always background)
2. Rely on FCM wake-up only
3. Original behavior preserved

## Related Documents

- [FCM Implementation](../FCM_IMPLEMENTATION.md)
- [Session Recovery Architecture](./SESSION_RECOVERY_ARCHITECTURE.md)
- [App Initialization Analysis](./APP_INITIALIZATION_ANALYSIS.md)

---

*Last updated: January 2026*
