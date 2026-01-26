# Fix 01: Foreground Service

## The Problem

Currently the background service runs in **background mode** (`isForegroundMode: false`), which means Android treats it as a low-priority process that can be killed at any time to free up resources.

Since Android 8 (Oreo), background execution limits are strict:
- Background services can only run for a few minutes
- The system aggressively kills background processes
- Apps in the background have limited CPU and network access

This explains why notifications work on some devices but not others - it depends on:
- How much RAM the device has
- What other apps are running
- The manufacturer's battery optimization aggressiveness

## Current Behavior

```
App goes to background
       ↓
Background service starts (low priority)
       ↓
Android may kill it anytime (unpredictable)
       ↓
WebSocket connections lost
       ↓
No notifications received
```

## Solution: Foreground Service

A **Foreground Service** is a service that:
- Shows a persistent notification to the user
- Has high priority and won't be killed by the system
- Can run indefinitely
- Has full network access even in Doze mode

### Trade-offs

| Aspect | Background Service | Foreground Service |
|--------|-------------------|-------------------|
| **Reliability** | Low - can be killed | High - protected |
| **User visibility** | None | Persistent notification |
| **Battery impact** | Lower (when running) | Slightly higher |
| **User perception** | Invisible | Visible notification |

## Implementation Options

### Option A: Always-on Foreground Service

When the app goes to background, start a foreground service that stays running until the app returns to foreground.

**Pros:**
- Maximum reliability
- Instant notifications
- Simple implementation

**Cons:**
- Persistent notification always visible
- Some users dislike persistent notifications
- Slightly higher battery usage

### Option B: Foreground Service with User Control

Let users choose in settings whether to use foreground service mode.

**Pros:**
- User choice
- Those who want reliability can have it
- Those who prefer no notification can accept less reliability

**Cons:**
- More complex UI/UX
- Users may not understand the trade-off
- Support burden explaining the feature

### Option C: Smart Foreground Service

Only show foreground service when there are active trades. When no active trades, run in background mode.

**Pros:**
- Notification only when relevant
- Better user experience
- Battery efficient when not trading

**Cons:**
- More complex logic
- Edge cases (what if trade starts while in background mode?)
- May miss the initial notification of a new trade action

## Recommendation

**Option A (Always-on)** for initial implementation because:
1. Simplest to implement correctly
2. Most reliable
3. Can iterate to Option B or C later based on user feedback

The notification can be made useful by showing:
- "Monitoring X active trades"
- "Connected to Y relays"
- Quick actions (open app, pause monitoring)

## Android Notification Channel

Need to create a proper notification channel for the foreground service:
- Channel ID: `mostro_background_service`
- Importance: LOW (no sound, minimized visual impact)
- Description: "Keeps Mostro connected for trade notifications"

Users can customize or disable the channel in Android settings if they want.

## What Changes

1. `mobile_background_service.dart` - Enable foreground mode
2. `background.dart` - Update notification content dynamically
3. `AndroidManifest.xml` - Ensure foreground service type is correct
4. Possibly add notification channel configuration

## Questions to Consider

1. What should the notification show?
2. Should it have action buttons?
3. Should it be dismissible? (Usually no for foreground services)
4. What icon to use?
5. Should the notification update with trade status?

## Related Issues

- This fix works best combined with Fix 02 (FCM starting service)
- If foreground service is killed despite being foreground (rare), FCM can restart it
