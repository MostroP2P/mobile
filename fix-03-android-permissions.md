# Fix 03: Android Permissions

## The Problem

The AndroidManifest is missing several permissions that are important for reliable background operation:

| Permission | Purpose | Current Status |
|------------|---------|----------------|
| `WAKE_LOCK` | Keep CPU awake during processing | **Missing** |
| `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` | Ask user to disable battery optimization | **Missing** |
| `RECEIVE_BOOT_COMPLETED` | Restart service after device reboot | **Missing** |

## Permission Details

### WAKE_LOCK

**What it does:** Allows the app to prevent the CPU from sleeping while performing important operations.

**Why needed:** When processing incoming Nostr events and showing notifications, the CPU must stay awake. Without this, the device might sleep mid-operation.

**User impact:** None visible. This is a normal permission that doesn't require user approval.

**Risk level:** Low. Only keeps CPU awake briefly during event processing.

### REQUEST_IGNORE_BATTERY_OPTIMIZATIONS

**What it does:** Allows the app to request being added to the battery optimization whitelist.

**Why needed:** Android's Doze mode and App Standby severely limit background network access. Being whitelisted allows:
- Unrestricted network access in background
- No delays on alarms and jobs
- Better WebSocket reliability

**User impact:**
- App can show a system dialog asking to disable battery optimization
- User must approve (can decline)
- User can change this later in settings

**Risk level:** Medium. Some users are wary of this permission. Should be explained clearly.

**Note:** This permission only allows *requesting* the exemption. User still has to approve.

### RECEIVE_BOOT_COMPLETED

**What it does:** Allows the app to receive a broadcast when the device finishes booting.

**Why needed:** If the user has active trades and reboots their phone, the background service should restart automatically to continue monitoring.

**User impact:** App will auto-start after reboot (if configured to do so).

**Risk level:** Low-Medium. Some users don't like apps auto-starting.

## Implementation Options

### Option A: Add All Permissions

Add all three permissions and implement the corresponding functionality.

**Pros:**
- Maximum reliability
- Best user experience for active traders

**Cons:**
- More permissions = more potential user concern
- Need to implement boot receiver
- Need to handle battery optimization request UX

### Option B: Add Only WAKE_LOCK

Start with the least controversial permission.

**Pros:**
- No user-visible changes
- Simple implementation
- Low risk

**Cons:**
- Doesn't solve battery optimization issues
- No boot persistence

### Option C: Gradual Rollout

1. First release: WAKE_LOCK only
2. Second release: Add RECEIVE_BOOT_COMPLETED
3. Third release: Add battery optimization request (with proper UX)

**Pros:**
- Can gauge user reaction
- Incremental complexity
- Can adjust based on feedback

**Cons:**
- Slower to reach full reliability
- Multiple releases needed

## Recommendation

**Option A** - Add all permissions, but implement them thoughtfully:

1. **WAKE_LOCK**: Just add it, no UI needed
2. **RECEIVE_BOOT_COMPLETED**: Add with setting to enable/disable auto-start
3. **REQUEST_IGNORE_BATTERY_OPTIMIZATIONS**: Add with proper explanation UI

## Battery Optimization UX

The battery optimization request needs careful UX design:

### When to Ask

Options:
1. On first app launch (too early, user doesn't understand why)
2. When user creates first order (relevant context)
3. When user enables a "Reliable notifications" setting
4. Never automatically, only from settings

**Recommendation:** Option 3 or 4. Let user opt-in with clear explanation.

### How to Explain

Bad: "Disable battery optimization"
Good: "To receive trade notifications reliably when the app is closed, Mostro needs permission to run in the background. This may slightly increase battery usage."

### The Dialog

Before showing the system dialog, show a custom dialog explaining:
- Why this is needed
- What happens if declined
- That they can change it later

## Boot Receiver Implementation

For RECEIVE_BOOT_COMPLETED:

1. Add BroadcastReceiver in AndroidManifest
2. On boot, check if there are active trades
3. If yes, start background service
4. If no, don't start (save battery)

Should also respect a user setting "Start on boot".

## What Changes

1. `AndroidManifest.xml` - Add permissions and boot receiver
2. New boot receiver class (Kotlin/Java or handle in Flutter)
3. Settings screen - Add auto-start toggle
4. New screen/dialog for battery optimization explanation
5. Utility to check and request battery optimization exemption

## OEM-Specific Considerations

Even with these permissions, some manufacturers require additional steps:

| Manufacturer | Additional Requirement |
|--------------|----------------------|
| Xiaomi | Enable "Autostart" in Security app |
| Samsung | Remove from "Sleeping apps" |
| Huawei | Add to "Protected apps" |
| OnePlus | Disable "Battery optimization" |
| Oppo/Vivo | Enable "Autostart" permission |

Consider adding a help section in app explaining these per-manufacturer.

## Testing

1. Test WAKE_LOCK by processing events with screen off
2. Test battery optimization by leaving app in background for hours
3. Test boot receiver by restarting device with active trades
4. Test on multiple OEMs if possible

## Related Issues

- These permissions support Fix 01 (Foreground Service) and Fix 02 (FCM Service Start)
- Without battery optimization exemption, even foreground service may have limited network
