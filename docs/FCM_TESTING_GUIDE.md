# FCM Testing Guide

## Quick Testing Checklist

### Prerequisites
- [ ] Firebase project configured (`mostro-test`)
- [ ] Cloud Functions deployed
- [ ] App installed on Android device
- [ ] FCM token registered (check logs on first app launch)

## Test Scenarios

### 1. Test Background Handler (App Killed)

**This is the critical test for the new implementation.**

#### Steps:
1. **Launch app and verify FCM initialization:**
   ```bash
   adb logcat | grep -i "fcm"
   ```
   Look for: `FCM INITIALIZATION COMPLETE`

2. **Kill the app completely:**
   - Swipe app from recent apps
   - OR: `adb shell am force-stop network.mostro.app`

3. **Trigger test notification:**
   ```bash
   curl -X POST https://YOUR-REGION-mostro-test.cloudfunctions.net/sendTestNotification
   ```

4. **Monitor background handler execution:**
   ```bash
   adb logcat | grep -E "FCM BACKGROUND|fetchAndProcessNewEvents"
   ```

5. **Expected logs:**
   ```
   [FCM] === FCM BACKGROUND WAKE START ===
   [FCM] Message data: {type: silent_wake, timestamp: 1234567890}
   [FCM] Loaded 1 relays from settings
   [FCM] Processing events from 1 relays...
   [FCM] Fetching new events from relays
   [FCM] Max events per session: 10
   [FCM] Timeout per session: 5s
   [FCM] Found X active sessions
   [FCM] Processed X new events successfully
   [FCM] Background event processing completed successfully
   [FCM] === FCM BACKGROUND WAKE END ===
   ```

6. **Verify notification appears:**
   - Check notification tray
   - Should show local notification with event details

#### Success Criteria:
- ✅ Background handler executes within 10 seconds
- ✅ Events are fetched and processed
- ✅ Local notification appears
- ✅ No timeout errors in logs

#### Common Issues:

**Issue:** No logs appear after test notification
- **Cause:** Battery optimization blocking background execution
- **Fix:** Disable battery optimization for the app
  ```bash
  adb shell dumpsys deviceidle whitelist +network.mostro.app
  ```

**Issue:** "No active sessions found"
- **Cause:** No active orders/trades in the app
- **Fix:** Create a test order first, then kill app and test

**Issue:** "Timeout fetching events for session"
- **Cause:** Relay not responding within 5 seconds
- **Fix:** Check relay connectivity or increase timeout

### 2. Test Foreground Handler (App Active)

#### Steps:
1. **Keep app open and in foreground**

2. **Trigger test notification:**
   ```bash
   curl -X POST https://YOUR-REGION-mostro-test.cloudfunctions.net/sendTestNotification
   ```

3. **Monitor foreground handler:**
   ```bash
   adb logcat | grep -i "foreground message"
   ```

4. **Expected logs:**
   ```
   [FCM] FCM foreground message received - processing events
   [FCM] Fetching new events from relays
   [FCM] Found X active sessions
   [FCM] Processed X new events successfully
   ```

#### Success Criteria:
- ✅ Handler executes immediately
- ✅ No limits applied (processes all events)
- ✅ Notifications appear

### 3. Test Fallback Mechanism (App Resume)

#### Steps:
1. **Simulate background processing failure:**
   - Kill app
   - Disconnect internet
   - Send test notification (will fail to process)
   - Reconnect internet

2. **Open app manually**

3. **Monitor resume handler:**
   ```bash
   adb logcat | grep -i "pending events"
   ```

4. **Expected logs:**
   ```
   [FCM] Pending events detected (background processing failed) - processing now
   [FCM] Fetching new events from 1 relays
   [FCM] Successfully processed pending events
   ```

#### Success Criteria:
- ✅ Pending flag detected on app open
- ✅ Events processed successfully
- ✅ Flag cleared after processing

### 4. Test Cloud Functions Poller

#### Check Poller Status:
```bash
curl https://YOUR-REGION-mostro-test.cloudfunctions.net/getStatus
```

**Expected response:**
```json
{
  "relays": ["wss://relay.mostro.network"],
  "lastCheckTimestamp": 1234567890,
  "lastCheckDate": "2024-01-01T12:00:00.000Z",
  "mostroPublicKey": "82fa8cb978b43c79b2156585bac2c011176a21d2aead6d9f7c575c005be88390",
  "fcmTopic": "mostro_notifications"
}
```

#### Monitor Cloud Functions Logs:
```bash
cd functions
npm run logs
```

**Expected logs (every 1 minute):**
```
Starting scheduled relay poll
Connected to wss://relay.mostro.network
Querying events since 1234567890
Found X new events from wss://relay.mostro.network
Polling complete - totalNewEvents: X
Found X new events, sending notification
Silent push notification sent successfully
```

### 5. End-to-End Test

**Complete flow test:**

1. **Setup:**
   - Create active order/trade in app
   - Note the order ID
   - Kill the app

2. **Simulate real event:**
   - Have another user interact with your order
   - OR: Use daemon to send test event

3. **Wait for notification:**
   - Cloud Functions polls every 1 minutes
   - Should detect new event
   - Should send silent push
   - Background handler should wake up
   - Should show notification

4. **Verify:**
   ```bash
   # Monitor entire flow
   adb logcat | grep -E "FCM|Mostro|notification"
   ```

5. **Expected timeline:**
   ```
   T+0s:   Event created in relay
   T+0-1m: Cloud Function detects event (next poll)
   T+0-1m: Silent push sent
   T+0-1m: Background handler wakes app
   T+0-1m: Events fetched and processed
   T+0-1m: Local notification shown
   ```

## Performance Testing

### Test Limits and Timeouts

#### Test with Many Events:
1. Create multiple orders
2. Generate many events
3. Kill app and trigger notification
4. Verify limits are applied:
   ```
   [FCM] Limiting to 10 events (skipped X)
   ```

#### Test Timeout Handling:
1. Use slow/unresponsive relay
2. Verify timeout logs:
   ```
   [FCM] Timeout fetching events for session
   ```

### Memory and Battery Testing

#### Monitor Memory Usage:
```bash
adb shell dumpsys meminfo network.mostro.app
```

#### Monitor Battery Usage:
```bash
adb shell dumpsys batterystats network.mostro.app
```

## Debugging Commands

### View All FCM-Related Logs:
```bash
adb logcat -s flutter,FCM,FirebaseMessaging
```

### Clear Logs and Start Fresh:
```bash
adb logcat -c
adb logcat | grep -i fcm
```

### Check SharedPreferences:
```bash
adb shell run-as network.mostro.app cat /data/data/network.mostro.app/shared_prefs/FlutterSharedPreferences.xml | grep fcm
```

### Force Background Handler:
```bash
# Send test notification while app is killed
adb shell am force-stop network.mostro.app
curl -X POST https://us-central1-mostro-test.cloudfunctions.net/sendTestNotification
```

## Troubleshooting

### No Background Handler Execution

**Check 1: FCM Token Registered**
```bash
adb logcat | grep "FCM token obtained"
```

**Check 2: Topic Subscription**
```bash
adb logcat | grep "Subscribed to topic"
```

**Check 3: Battery Optimization**
```bash
adb shell dumpsys deviceidle whitelist | grep mostro
```

**Check 4: Background Restrictions**
```bash
adb shell cmd appops get network.mostro.app RUN_IN_BACKGROUND
```

### Background Handler Crashes

**View Crash Logs:**
```bash
adb logcat -s AndroidRuntime,System.err
```

**Common causes:**
- Out of memory (reduce limits)
- Timeout (reduce timeout or event count)
- Database access issues (check permissions)

### Events Not Fetched

**Check 1: Relay Connectivity**
```bash
# Test relay connection
wscat -c wss://relay.mostro.network
```

**Check 2: Settings Loaded**
```bash
adb logcat | grep "Loaded.*relays from settings"
```

**Check 3: Active Sessions**
```bash
adb logcat | grep "Found.*active sessions"
```

## Success Metrics

### What to Measure

1. **Notification Delivery Time:**
   - From event creation to notification shown
   - Target: < 2 minutes (1min poll + processing time)

2. **Background Handler Success Rate:**
   - Percentage of successful background executions
   - Target: > 95%

3. **Event Processing Rate:**
   - Number of events processed per session
   - Monitor for limit hits

4. **Battery Impact:**
   - Background handler execution time
   - Target: < 10 seconds per execution

## Test Results Template

```markdown
## Test Results - [Date]

### Environment
- Device: [Model]
- Android Version: [Version]
- App Version: [Version]
- Firebase Project: mostro-test

### Test 1: Background Handler (App Killed)
- [ ] Background handler executed
- [ ] Events fetched successfully
- [ ] Notifications shown
- [ ] Time to notification: [X] seconds
- Notes: [Any issues or observations]

### Test 2: Foreground Handler
- [ ] Handler executed
- [ ] Events processed
- [ ] Notifications shown
- Notes: [Any issues or observations]

### Test 3: Fallback Mechanism
- [ ] Pending flag set
- [ ] Events processed on resume
- [ ] Flag cleared
- Notes: [Any issues or observations]

### Test 4: Cloud Functions
- [ ] Poller running every 5 minutes
- [ ] Events detected correctly
- [ ] Silent push sent
- Notes: [Any issues or observations]

### Test 5: End-to-End
- [ ] Complete flow successful
- [ ] Notification received within 6 minutes
- [ ] Content decrypted correctly
- Notes: [Any issues or observations]

### Performance
- Background handler execution time: [X]s
- Memory usage: [X]MB
- Battery impact: [Low/Medium/High]

### Issues Found
1. [Issue description]
2. [Issue description]

### Recommendations
1. [Recommendation]
2. [Recommendation]
```

## Automated Testing

### Consider Adding:

1. **Integration Tests:**
   ```dart
   testWidgets('FCM background handler processes events', (tester) async {
     // Test background handler
   });
   ```

2. **Mock FCM Messages:**
   ```dart
   final mockMessage = RemoteMessage(
     data: {'type': 'silent_wake', 'timestamp': '1234567890'},
   );
   await firebaseMessagingBackgroundHandler(mockMessage);
   ```

3. **CI/CD Integration:**
   - Run tests on each commit
   - Monitor notification delivery rates
   - Alert on failures

## Next Steps

After successful testing:

1. **Monitor Production:**
   - Set up Firebase Analytics
   - Track notification delivery rates
   - Monitor error rates

2. **Gather User Feedback:**
   - Survey users about notification reliability
   - Track battery usage complaints
   - Monitor app reviews

3. **Optimize:**
   - Adjust limits based on real usage
   - Fine-tune timeouts
   - Improve error handling

4. **Document:**
   - Update this guide with findings
   - Share best practices with team
   - Create troubleshooting runbook
