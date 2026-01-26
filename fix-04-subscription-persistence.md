# Fix 04: Subscription Persistence

## The Problem

Active subscriptions are stored only in memory:

```dart
final Map<String, Map<String, dynamic>> activeSubscriptions = {};
```

When the background service is killed and restarted (by FCM, boot, or manual), it has no memory of what it should be subscribed to. The service starts but listens to nothing.

## Current Flow (Broken)

```
Service starts
       ↓
Receives subscriptions from LifecycleManager
       ↓
Stores in memory (activeSubscriptions map)
       ↓
[Service killed by Android]
       ↓
Service restarts (via FCM or boot)
       ↓
activeSubscriptions is empty
       ↓
Service running but not subscribed to anything
       ↓
❌ No events received
```

## Desired Flow

```
Service starts
       ↓
Receives subscriptions from LifecycleManager
       ↓
Stores in memory AND persists to storage
       ↓
[Service killed by Android]
       ↓
Service restarts (via FCM or boot)
       ↓
Loads subscriptions from storage
       ↓
Re-subscribes to all filters
       ↓
✅ Events received, notifications shown
```

## What Needs to Be Persisted

For each subscription:
- Subscription ID (can be regenerated)
- Nostr filters (kinds, authors, p tags, since, etc.)
- Subscription type (orders, chat, relay list)

The filters contain:
- `kinds`: [1059] for gift-wrapped messages
- `#p`: List of trade public keys to monitor
- `since`: Timestamp to avoid old events

## Implementation Options

### Option A: SharedPreferences

Store serialized filters in SharedPreferences.

**Pros:**
- Simple, already used in the project
- Synchronous reads available
- Works across isolates

**Cons:**
- Not ideal for complex data structures
- Size limits (though unlikely to hit them)
- Manual serialization needed

### Option B: Sembast Database

Use the existing Sembast database infrastructure.

**Pros:**
- Already have database setup
- Better for structured data
- Consistent with rest of app

**Cons:**
- Async only
- Slightly more complex
- Need to handle database in background isolate

### Option C: Hybrid

Use SharedPreferences for quick access to "should restore?" flag and basic info.
Use Sembast for full filter details.

**Pros:**
- Fast startup check
- Full data when needed
- Best of both worlds

**Cons:**
- Most complex
- Two storage systems to maintain

## Recommendation

**Option A (SharedPreferences)** for simplicity:
1. Filters are relatively small (JSON serializable)
2. Already have SharedPreferences access in background
3. Quick to implement
4. Can migrate to Option B later if needed

## Key Considerations

### 1. When to Save

- When subscriptions are created (`create-subscription` event)
- When subscriptions are modified
- When subscriptions are cancelled

### 2. When to Load

- On service start (both fresh start and restart)
- Before the service signals "ready"

### 3. Staleness Handling

Persisted subscriptions might be stale if:
- App was updated
- Settings changed while service was dead
- Active trades completed while service was dead

Solutions:
- Store a version number with subscriptions
- On app launch, always refresh subscriptions
- Add timestamp and consider subscriptions older than X hours as stale

### 4. The `since` Timestamp Problem

Nostr filters often include a `since` timestamp to avoid receiving old events. If we persist filters with old `since` values:
- On restart, might miss events that happened while service was dead
- On restart, might receive duplicate events

Solution: On restore, update `since` to a recent timestamp (e.g., 5 minutes ago) or store last processed event timestamp.

### 5. Synchronization with Main App

When main app starts:
1. It will send new subscriptions to service
2. Service might have restored old ones
3. Need to handle this cleanly (replace old with new)

## Data Structure

```
{
  "subscriptions_version": 1,
  "last_updated": 1706234567,
  "subscriptions": [
    {
      "id": "sub_123",
      "type": "orders",
      "filters": {
        "kinds": [1059],
        "#p": ["pubkey1", "pubkey2"],
        "since": 1706234000
      }
    }
  ]
}
```

## What Changes

1. `background.dart` - Add save/load logic
2. New utility class for subscription storage
3. Service startup sequence - load before connecting
4. Handle version/staleness on load

## Edge Cases

1. **Storage is corrupted**: Clear and wait for app to resend
2. **No stored subscriptions on restart**: Service idles until app provides them
3. **Very old subscriptions**: Apply staleness policy
4. **Storage full**: Unlikely, but handle gracefully

## Testing

1. Service killed → restarted → should restore subscriptions
2. Device rebooted → service starts → should restore subscriptions
3. App sends new subscriptions → should replace old ones
4. Corrupted storage → should handle gracefully
5. Very old subscriptions → should update `since` timestamp

## Related Issues

- This fix is essential for Fix 02 (FCM Service Start) to work properly
- Without persistence, restarted service does nothing
- Works with Fix 05 (Heartbeat) for connection health
