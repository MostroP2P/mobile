# FCM Push Notifications Implementation

## Overview

This document describes the Firebase Cloud Messaging (FCM) implementation for MostroP2P mobile app. The system is designed to wake up the app when killed by Android and deliver notifications while **preserving user privacy** - Firebase never sees the content of messages.

## Architecture

### Privacy-First Design

```
┌─────────────────┐      ┌──────────────────┐      ┌─────────────────┐
│  Nostr Relay    │─────▶│ Firebase         │─────▶│  Mobile App     │
│  (Events)       │      │ Cloud Functions  │      │  (Background)   │
│                 │      │                  │      │                 │
│ • Kind 1059     │      │ • Polls relay    │      │ • Wakes up      │
│ • Encrypted     │      │ • Counts events  │      │ • Fetches events│
│                 │      │ • NO decryption  │      │ • Decrypts      │
│                 │      │ • Sends silent   │      │ • Shows notif   │
│                 │      │   push (no data) │      │                 │
└─────────────────┘      └──────────────────┘      └─────────────────┘
```

**Key Privacy Features:**
- ✅ Firebase Functions only **count** new events, never decrypt content
- ✅ Silent push notifications contain **no user data**
- ✅ All decryption happens **locally** on the device
- ✅ Firebase never sees message content, order details, or user info

## Components

### 1. Backend: Firebase Cloud Functions

**Location:** `/functions/src/index.ts`

**Functions:**
- `keepAlive` - Scheduled function (every 1 minute)
  - Polls Nostr relay for new events (kind 1059)
  - Tracks last check timestamp
  - Sends silent push if new events found
  
- `sendTestNotification` - HTTP endpoint for testing
- `getStatus` - HTTP endpoint to check poller status

**Configuration:**
```typescript
const NOSTR_RELAYS = ["wss://relay.mostro.network"];
const MOSTRO_PUBKEY = "82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390";
const FCM_TOPIC = "mostro_notifications";
```

**Silent Push Format:**
```typescript
{
  topic: "mostro_notifications",
  data: {
    type: "silent_wake",
    timestamp: "1234567890"
  },
  android: {
    priority: "high",
    notification: undefined  // Silent - no visible notification
  }
}
```

### 2. Mobile App: Background Handler

**Location:** `/lib/main.dart`

**Background Message Handler:**
```dart
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // 1. Initialize Firebase
  // 2. Load relay configuration from SharedPreferences
  // 3. Process events directly (fetchAndProcessNewEvents)
  // 4. Decrypt and show local notifications
  // 5. Update timestamp or set retry flag
}
```

**Key Features:**
- Runs when app is **killed** by Android
- Loads relay config from local storage
- Processes events with **limits** to avoid timeout:
  - Max 10 events per session
  - 5 second timeout per session
- Falls back to retry flag if processing fails

### 3. Mobile App: Foreground Handler

**Location:** `/lib/shared/providers/app_init_provider.dart`

**Foreground Message Handler:**
```dart
onMessageReceived: () async {
  // Process events without limits (app is active)
  await fetchAndProcessNewEvents(relays: relays);
}
```

### 4. Event Processing Service

**Location:** `/lib/features/notifications/services/background_notification_service.dart`

**Function:** `fetchAndProcessNewEvents()`

**Parameters:**
- `relays` - List of Nostr relays to query
- `maxEventsPerSession` - Optional limit (used in background)
- `timeoutPerSession` - Timeout per session (default 10s)

**Process:**
1. Load active sessions from database
2. For each session:
   - Query relay for new events (kind 1059)
   - Apply timeout and limits
   - Decrypt events locally
   - Show local notifications
3. Update last processed timestamp

## Flow Diagrams

### When App is Killed

```
1. Firebase Function detects new events (polls every 1 minute)
   ↓
2. Sends silent push to FCM topic
   ↓
3. Android wakes app (background handler)
   ↓
4. Load relay config from SharedPreferences
   ↓
5. Fetch events from Nostr relays (with limits)
   ↓
6. Decrypt locally with session keys
   ↓
7. Show local notification
   ↓
8. Update timestamp
```

### When App is Active (Foreground)

```
1. Firebase Function detects new events (polls every 1 minute)
   ↓
2. Sends silent push to FCM topic
   ↓
3. Foreground handler receives message
   ↓
4. Fetch events from Nostr relays (no limits)
   ↓
5. Decrypt locally with session keys
   ↓
6. Show local notification
   ↓
7. Update timestamp
```

### Fallback: App Resume

```
1. Background processing failed
   ↓
2. Set 'fcm.pending_fetch' flag
   ↓
3. User opens app manually
   ↓
4. _checkPendingEventsOnResume() detects flag
   ↓
5. Process pending events (no limits)
   ↓
6. Clear flag
```

## Configuration

### Firebase Project Setup

1. Create Firebase project: `mostro-test`
2. Add Android app with package: `network.mostro.app`
3. Download `google-services.json` to `/android/app/`
4. Configure FCM in Firebase Console

### Mobile App Configuration

**pubspec.yaml:**
```yaml
dependencies:
  firebase_core: ^3.8.0
  firebase_messaging: ^15.1.4
```

**AndroidManifest.xml:**
```xml
<meta-data
  android:name="com.google.firebase.messaging.default_notification_icon"
  android:resource="@drawable/ic_bg_service_small" />
```

### Cloud Functions Deployment

```bash
cd functions
npm install
npm run deploy
```

## Testing

### Test Silent Push

```bash
# Send test notification
curl -X POST https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/sendTestNotification

# Check poller status
curl https://YOUR-REGION-YOUR-PROJECT.cloudfunctions.net/getStatus
```

### Monitor Logs

**Cloud Functions:**
```bash
cd functions
npm run logs
```

**Mobile App:**
```bash
flutter run
# Look for logs:
# - "=== FCM BACKGROUND WAKE START ==="
# - "Loaded X relays from settings"
# - "Processing events from X relays..."
# - "Background event processing completed successfully"
```

### Debug Background Handler

1. Kill app completely (swipe from recent apps)
2. Send test notification from Firebase Console or curl
3. Check logcat for background handler logs:
```bash
adb logcat | grep -i "fcm\|mostro"
```

## Limitations

### Android Background Execution

- **Time limit:** ~30 seconds for background handler
- **Solution:** Implemented limits (10 events, 5s timeout per session)
- **Fallback:** Retry flag for app resume

### Battery Optimization

- Some Android devices may restrict background execution
- Users may need to disable battery optimization for the app
- Consider adding in-app prompt for battery optimization settings

### Cold Start

- First notification after app install may be delayed
- FCM token needs to be registered with Firebase
- Subsequent notifications work normally

## Monitoring

### Key Metrics to Track

1. **Cloud Functions:**
   - Execution count (should run every 5 minutes)
   - Event detection rate
   - Push notification send success rate

2. **Mobile App:**
   - Background handler execution count
   - Event processing success rate
   - Fallback flag usage (indicates background failures)
   - Notification display rate

### Logs to Monitor

**Success indicators:**
```
[FCM] Background event processing completed successfully
[FCM] Processed X new events successfully
```

**Warning indicators:**
```
[FCM] Timeout fetching events for session
[FCM] Limiting to 10 events (skipped X)
[FCM] Error processing events in background
```

**Failure indicators:**
```
[FCM] Critical error in background handler
[FCM] Failed to initialize NostrService
[FCM] No active sessions found
```

## Troubleshooting

### Notifications Not Arriving When App is Killed

1. Check Cloud Functions logs - is poller running?
2. Check if events are being detected in relay
3. Verify FCM token is registered
4. Check Android battery optimization settings
5. Review background handler logs in logcat

### Background Processing Timeout

1. Reduce `maxEventsPerSession` (currently 10)
2. Reduce `timeoutPerSession` (currently 5s)
3. Check relay response times
4. Consider processing fewer sessions

### High Battery Usage

1. Verify Cloud Functions polling interval (5 minutes)
2. Check if background handler is being called too frequently
3. Review event processing efficiency
4. Consider increasing polling interval

## Future Improvements

### Potential Enhancements

1. **Adaptive Limits:** Adjust limits based on device performance
2. **Priority Queue:** Process high-priority events first
3. **Batch Processing:** Group multiple events per notification
4. **User Preferences:** Allow users to configure notification behavior
5. **Analytics:** Track notification delivery and user engagement

### Alternative Approaches

1. **WorkManager:** Use WorkManager for guaranteed background execution
2. **Foreground Service:** Keep app alive with foreground service
3. **WebSocket Keepalive:** Maintain persistent connection (battery intensive)

## Security Considerations

### What Firebase Sees

- ✅ Device FCM token (anonymous identifier)
- ✅ Topic subscription (`mostro_notifications`)
- ✅ Timestamp of notification delivery
- ❌ **NEVER sees:** Message content, order details, user data

### What's Encrypted

- All Nostr events (kind 1059) are encrypted with NIP-44
- Decryption keys stored locally in secure storage
- Firebase Functions never have access to decryption keys

### Attack Vectors

1. **Timing Analysis:** Firebase could correlate notification times with user activity
   - **Mitigation:** Polling interval adds noise (1 minute)

2. **Device Fingerprinting:** FCM token could be used to track devices
   - **Mitigation:** Token is rotated periodically by FCM

3. **Relay Monitoring:** Someone monitoring relay could correlate with push timing
   - **Mitigation:** Multiple users share same relay, adds ambiguity

## Conclusion

This implementation successfully balances:
- ✅ **Privacy:** No sensitive data shared with Firebase
- ✅ **Reliability:** Notifications work when app is killed
- ✅ **Performance:** Limits prevent timeouts and battery drain
- ✅ **User Experience:** Timely notifications without manual app opening

The system leverages FCM purely as a **wake-up mechanism**, with all sensitive operations (decryption, processing) happening locally on the device.
