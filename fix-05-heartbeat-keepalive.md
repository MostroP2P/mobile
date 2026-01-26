# Fix 05: Heartbeat / Keep-Alive Mechanism

## The Problem

WebSocket connections can die silently without either side knowing. This happens due to:

1. **NAT Timeout**: Routers/carriers close idle connections (typically 30-60 seconds)
2. **Android Doze Mode**: Network access is restricted, connections may drop
3. **Carrier Network Switching**: Moving between cell towers can break connections
4. **Server-side Timeouts**: Relays may close idle connections
5. **Proxy/Firewall Timeouts**: Corporate or ISP proxies killing idle connections

When this happens:
- The WebSocket appears open locally
- No error is thrown
- No events are received
- App thinks it's connected but isn't

## Current State

The `dart_nostr` library has `retryOnClose: true` and `retryOnError: true`, but:
- These only trigger when the connection is **known** to be closed
- Silent connection death is not detected
- No proactive health checking

## How WebSocket Keep-Alive Works

### Ping/Pong (WebSocket Protocol Level)

WebSocket protocol has built-in ping/pong frames:
- Client sends PING frame
- Server responds with PONG frame
- If no PONG within timeout, connection is dead

### Application-Level Heartbeat

Send actual Nostr messages periodically:
- Send a REQ for something harmless
- Expect a response (EOSE or events)
- No response = connection dead

## Implementation Options

### Option A: WebSocket-Level Ping

Use the WebSocket's ping/pong mechanism.

**Pros:**
- Protocol standard
- Low overhead
- Handled at transport level

**Cons:**
- `dart_nostr` may not expose this
- Not all relays/proxies handle pings correctly
- Requires library modification or workaround

### Option B: Application-Level Heartbeat

Periodically send a Nostr REQ and expect EOSE.

**Pros:**
- Works with any relay
- Tests full path (not just TCP)
- No library changes needed

**Cons:**
- Slightly more overhead
- Need to filter out heartbeat responses
- More complex implementation

### Option C: Periodic Reconnection

Instead of detecting dead connections, proactively reconnect every N minutes.

**Pros:**
- Simplest implementation
- Guarantees fresh connection
- No detection logic needed

**Cons:**
- Wasteful (reconnects even when healthy)
- Brief interruption during reconnect
- May miss events during reconnect window

### Option D: Hybrid Approach

1. Application-level heartbeat every 30 seconds
2. If heartbeat fails, force reconnection
3. Periodic reconnection every 15-30 minutes as safety net

**Pros:**
- Best reliability
- Detects problems quickly
- Safety net for edge cases

**Cons:**
- Most complex
- More battery/network usage

## Recommendation

**Option D (Hybrid)** for maximum reliability:

1. Every 30 seconds: Send lightweight heartbeat
2. If no response in 10 seconds: Mark connection suspect
3. If 2 consecutive failures: Force reconnect
4. Every 20 minutes: Force reconnect regardless (safety net)

## Heartbeat Design

### What to Send

Best approach: Send a REQ with impossible filter that will immediately get EOSE:
```json
{
  "kinds": [99999],  // Non-existent kind
  "limit": 1
}
```

Server will respond with EOSE immediately. This:
- Tests full path
- Minimal data transfer
- Doesn't interfere with real subscriptions

### Response Handling

- Receive EOSE within timeout: Connection healthy
- No response: Connection dead or slow
- Use separate subscription ID for heartbeat (e.g., `heartbeat_xxx`)
- Clean up heartbeat subscription after response

### Timing Considerations

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Heartbeat interval | 30s | Less than typical NAT timeout (60s) |
| Response timeout | 10s | Generous for slow networks |
| Failure threshold | 2 | Avoid false positives |
| Force reconnect interval | 20min | Safety net |

## Battery Considerations

Frequent network activity impacts battery. Mitigations:
- Only heartbeat when service is actually running
- Batch with other network activity if possible
- Reduce frequency when on battery saver mode (if detectable)
- Skip heartbeat if recent real activity occurred

## Reconnection Strategy

When reconnection is needed:

1. Close existing connections
2. Wait brief moment (100ms)
3. Reinitialize NostrService
4. Resubscribe to all active filters
5. Update UI/state if needed

## Integration with Background Service

The heartbeat should run in the background isolate:
1. Heartbeat timer starts when service starts
2. Timer runs independently of subscriptions
3. On connection failure, trigger reconnect
4. After reconnect, restore all subscriptions (from persistence - Fix 04)

## What Changes

1. `background.dart` - Add heartbeat timer and logic
2. `nostr_service.dart` - Add reconnection method
3. New heartbeat utility class
4. Connection state tracking

## Monitoring and Logging

Important to log:
- Heartbeat sent/received
- Connection failures detected
- Reconnection attempts
- Reconnection success/failure

This helps debug issues in the field.

## Edge Cases

1. **Heartbeat during actual event**: Don't double-count as healthy
2. **Multiple relays**: Heartbeat each independently
3. **Reconnect while event processing**: Queue events, don't lose them
4. **Rapid reconnection loop**: Add exponential backoff
5. **Network completely unavailable**: Don't spin, wait for connectivity

## Testing

1. Simulate NAT timeout (hard to test, may need proxy)
2. Enable airplane mode briefly → should recover
3. Switch between WiFi and cellular → should recover
4. Server restart → should reconnect
5. Verify no memory leaks from heartbeat timers

## Related Issues

- Works with Fix 04 (Subscription Persistence) for reconnection
- Works with Fix 01 (Foreground Service) for reliable timer execution
- May need WAKE_LOCK (Fix 03) to ensure heartbeat runs
