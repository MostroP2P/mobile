# Fix 07: OEM-Specific Battery Optimization

## The Problem

Android phone manufacturers add their own battery optimization layers on top of stock Android. These are often aggressive and kill background apps even when:
- The app has all permissions
- Battery optimization is disabled in Android settings
- The app is running a foreground service

This is a major source of the "works on some phones, not others" problem.

## OEM-Specific Behaviors

### Xiaomi (MIUI)

**Behavior:**
- Has "Autostart" permission (disabled by default)
- "Battery Saver" can kill any background app
- "Lock" feature in recents prevents killing
- MIUI Security app manages app permissions

**Required User Actions:**
1. Settings → Apps → Manage apps → [App] → Autostart: Enable
2. Settings → Battery & performance → Battery saver → Choose apps → [App] → No restrictions
3. Optionally: Long press app in recents → Lock

### Samsung (One UI)

**Behavior:**
- "Sleeping apps" list (apps that can't run in background)
- "Deep sleeping apps" list (more restrictive)
- "Adaptive battery" learns and restricts apps

**Required User Actions:**
1. Settings → Apps → [App] → Battery → Allow background activity
2. Settings → Battery → Background usage limits → Never sleeping apps → Add [App]
3. Settings → Battery → Background usage limits → Remove from sleeping/deep sleeping

### Huawei (EMUI)

**Behavior:**
- "Protected apps" list
- "Battery optimization" with multiple modes
- Startup manager controls autostart

**Required User Actions:**
1. Settings → Battery → App launch → [App] → Manage manually → Enable all toggles
2. Phone Manager → Protected apps → Enable [App]
3. Settings → Apps → Startup manager → [App] → Enable

### OnePlus (OxygenOS)

**Behavior:**
- "Battery optimization" similar to stock but more aggressive
- "Optimize battery use" setting

**Required User Actions:**
1. Settings → Apps → [App] → Battery → Don't optimize
2. Settings → Battery → Battery optimization → [App] → Don't optimize

### Oppo (ColorOS) / Vivo (FuntouchOS)

**Behavior:**
- Autostart permission required
- "High power consumption" warnings
- Background process limits

**Required User Actions:**
1. Settings → App Management → App list → [App] → Battery usage → Allow background
2. Settings → App Management → Autostart manager → Enable [App]
3. For Vivo: i Manager → App manager → Autostart manager → Enable [App]

### Realme (Realme UI)

**Behavior:**
- Similar to Oppo (based on ColorOS)
- "Battery optimization" setting

**Required User Actions:**
1. Settings → Battery → More settings → Optimize battery → [App] → Don't optimize
2. Settings → App Management → Autostart → Enable [App]

## Implementation Options

### Option A: In-App Instructions

Show detailed, manufacturer-specific instructions within the app.

**Pros:**
- Always available
- Can be localized
- No external dependencies

**Cons:**
- UI can get cluttered
- Instructions may become outdated
- Users may not read them

### Option B: Link to External Resource

Maintain a webpage with instructions, link from app.

**Pros:**
- Easy to update
- More detailed instructions
- Can include screenshots

**Cons:**
- Requires internet
- External dependency
- Need to maintain website

### Option C: Automated Detection and Deep Links

Detect manufacturer and open the correct settings page.

**Pros:**
- Best UX
- One-tap to correct screen
- Smart and modern

**Cons:**
- Deep link intents vary by OEM/version
- May break with updates
- Complex to maintain

### Option D: DontKillMyApp.com Integration

Use the existing dontkillmyapp.com resource.

**Pros:**
- Already comprehensive
- Community maintained
- Covers many devices

**Cons:**
- External dependency
- No app control over content
- May not be localized

## Recommendation

**Hybrid approach:**

1. **Detect manufacturer** using device info
2. **Show in-app summary** specific to detected manufacturer
3. **Provide "Open Settings" button** that tries to deep link
4. **Link to dontkillmyapp.com** for detailed instructions

## Detection

```dart
import 'dart:io';

String getManufacturer() {
  if (Platform.isAndroid) {
    // Use device_info_plus package
    // Returns: 'xiaomi', 'samsung', 'huawei', 'oneplus', etc.
  }
  return 'unknown';
}
```

## Deep Link Intents (Examples)

These may work but aren't guaranteed:

| Manufacturer | Intent |
|--------------|--------|
| Xiaomi | `miui.intent.action.AUTOSTART` |
| Samsung | `com.samsung.android.lool.SETTINGS_ACTIVITY` |
| Huawei | `huawei.intent.action.HSM_BOOTAPP_MANAGER` |
| Oppo | `com.coloros.safecenter.permission.startup` |

These change frequently. Need fallback to generic settings.

## UX Considerations

### When to Show

Options:
1. On first launch (too early, overwhelming)
2. After first trade created (relevant context)
3. In settings, under "Troubleshooting"
4. When notification issue detected (smart but hard to detect)

**Recommendation:** Option 3, with optional prompt after trade creation

### How to Present

1. **Notification troubleshooting section** in Settings
2. Detect manufacturer and show relevant card
3. Step-by-step instructions with "Open Settings" buttons
4. "Learn more" link to dontkillmyapp.com
5. "My device isn't listed" fallback

### Localization

Instructions should be localized. The settings screen names differ by:
- Language
- OEM
- Android version

Consider showing screenshots or keeping text generic.

## What Changes

1. Add `device_info_plus` package (if not present)
2. New screen: "Notification Troubleshooting" or "Battery Settings"
3. Manufacturer detection utility
4. Per-manufacturer instruction content
5. Deep link utilities with fallbacks
6. Link to dontkillmyapp.com

## The "Don't Kill My App" Initiative

Website: https://dontkillmyapp.com

This site:
- Ranks manufacturers by how aggressive they are
- Provides per-device instructions
- Has API for integration
- Community maintained

Consider contributing Mostro's experience back to the site.

## Alternative Approach: Server-Side Push

Instead of trying to keep background service alive, rely more heavily on FCM:
- FCM can wake the app even when killed
- Process event, show notification, go back to sleep
- Less battery usage
- Works on aggressive OEMs

However, this requires:
- Server-side push infrastructure
- More latency (push notification delay)
- May not work in regions where FCM is blocked

Current architecture already uses FCM as backup, so both approaches can coexist.

## Testing Matrix

Need to test on various devices:

| Priority | Manufacturer | Model | MIUI/One UI Version |
|----------|--------------|-------|---------------------|
| High | Xiaomi | Various | MIUI 12, 13, 14 |
| High | Samsung | Galaxy A/S series | One UI 4, 5, 6 |
| Medium | Huawei | P/Mate series | EMUI 11, 12 |
| Medium | OnePlus | Various | OxygenOS 11, 12, 13 |
| Low | Oppo | Various | ColorOS 11, 12, 13 |
| Low | Vivo | Various | FuntouchOS |

## Related Issues

- This complements Fix 01 (Foreground Service) - even foreground services can be killed by OEMs
- This complements Fix 02 (FCM) - FCM as fallback when service is killed
- This is about user education, other fixes are technical
