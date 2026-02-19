# Chat Notifications Implementation Plan

## Problem Statement

Push and background notifications currently only work for Mostro-originated events (order updates, timeout detection, cancellations). Chat messages between users (P2P) and between users and admins (disputes) do not generate any notifications — not in background, not in foreground (outside the chat screen), and not via FCM when the app is killed.

## Current Architecture Summary

### Notification Pipeline (Mostro events only)
```
Mostro daemon → kind 1059 event (p=tradeKey.public) → relay
    ↓
Push server monitors relays → matches p tag → silent FCM → app wakes
    ↓
background.dart serviceMain → event arrives via subscription
    ↓
_decryptAndProcessEvent() → match session by tradeKey.public == event.recipient
    ↓
event.unWrap(tradeKey.private) → jsonDecode → MostroMessage.fromJson(result[0])
    ↓
NotificationDataExtractor → NotificationMessageMapper → local notification
```

### Three Message Types

| Type | Encryption | p tag | Unwrap | Inner format |
|------|-----------|-------|--------|-------------|
| Mostro events | NIP-59 full (Rumor→Seal→GiftWrap) | `tradeKey.public` | `unWrap(tradeKey.private)` | `[{action, id, payload}]` |
| P2P chat | NIP-59 simplified (Inner→GiftWrap) | `sharedKey.public` | `p2pUnwrap(sharedKey)` | Plain text in kind 1 |
| Admin/dispute chat | NIP-59 full (Rumor→Seal→GiftWrap) | `tradeKey.public` | `mostroUnWrap(tradeKey)` | `[{"dm": {"action": "send-dm", "payload": {"text_message": "..."}}}]` |

### What Fails and Why

**P2P Chat:**
- Background subscriptions transfer chat filters (sharedKey.public) — events arrive
- `_decryptAndProcessEvent()` matches only by `tradeKey.public` — **never matches sharedKey.public**
- Even if matched, pipeline expects `MostroMessage` JSON array, not plain text
- Push server only has tradeKey registered — doesn't know about sharedKey
- No in-app notification when user is outside the chat screen

**Admin/Dispute Chat:**
- Events arrive at `tradeKey.public` — subscription matches
- `event.unWrap(tradeKey.private)` works (same decryption as Mostro events)
- Content parsing **fails**: expects `MostroMessage` but receives `{"dm": {...}}` format
- Push/FCM already works (push server monitors tradeKey on relays)
- No in-app notification when user is outside the dispute chat screen

### Key Insight: sharedKey Available in Background

`_loadSessionsFromDatabase()` restores full sessions including peer info. Setting `session.peer` automatically computes `sharedKey = ECDH(tradeKey.private, peer.publicKey)`. This is **not a blocker**.

---

## Implementation Phases

### Phase 1: Admin/Dispute Chat Background Notifications

**Scope:** Detect and display generic notifications for admin DM messages that arrive in background.

**Why first:** Admin DMs already arrive at `tradeKey.public`, already get decrypted by `unWrap()` — only the parsing step fails. This is the smallest change with immediate value.

**Changes:**

#### 1.1 Modify `_decryptAndProcessEvent()` in `background_notification_service.dart`

After successful `unWrap` and `jsonDecode`, before attempting `MostroMessage.fromJson`:

```dart
// Current: always tries MostroMessage.fromJson(result[0])
// New: detect DM format first
final firstItem = result[0];
if (firstItem is Map && firstItem.containsKey('dm')) {
  // Admin DM message — show generic chat notification
  return _createChatNotification(event, matchingSession);
}
// Existing MostroMessage path continues...
```

#### 1.2 Add `_createChatNotification()` helper

Returns a lightweight object (not MostroMessage) that triggers a generic notification:
- Title: "New message" (localized)
- Body: "You have a new message in your trade" (localized)
- No message content exposed

#### 1.3 Modify `showLocalNotification()` to handle chat notifications

Add a parallel path that skips `NotificationDataExtractor` (which expects MostroMessage) and goes directly to notification display with generic text.

#### 1.4 Add localization keys to ARB files

New keys for all 3 languages (en, es, it):
- `chat_notification_title`: "New Message" / "Nuevo Mensaje" / "Nuovo Messaggio"
- `chat_notification_body`: "You have a new message in your trade" / "Tienes un nuevo mensaje en tu operacion" / "Hai un nuovo messaggio nella tua operazione"

**Files to modify:**
- `lib/features/notifications/services/background_notification_service.dart`
- `lib/l10n/intl_en.arb`
- `lib/l10n/intl_es.arb`
- `lib/l10n/intl_it.arb`

**Tests:**
- Unit test: verify DM format detection in `_decryptAndProcessEvent` mock path
- Unit test: verify generic notification text generation

---

### Phase 2: P2P Chat Background Notifications

**Scope:** Detect and display generic notifications for P2P chat messages that arrive in background.

**Why second:** Requires adding sharedKey matching path — slightly more complex than Phase 1 but still isolated to the background service.

**Changes:**

#### 2.1 Add sharedKey matching in `_decryptAndProcessEvent()`

After the existing tradeKey match fails (returns null), add a second lookup:

```dart
// Existing: match by tradeKey.public
final tradeKeyMatch = sessions.cast<Session?>().firstWhere(
  (s) => s?.tradeKey.public == event.recipient,
  orElse: () => null,
);

if (tradeKeyMatch != null) {
  // ... existing Mostro + Phase 1 admin DM path
}

// NEW: match by sharedKey.public for P2P chat
final chatMatch = sessions.cast<Session?>().firstWhere(
  (s) => s?.sharedKey?.public == event.recipient,
  orElse: () => null,
);

if (chatMatch != null) {
  return _handleP2PChatEvent(event, chatMatch);
}
```

#### 2.2 Add `_handleP2PChatEvent()` method

- Calls `event.p2pUnwrap(session.sharedKey!)` to decrypt
- Does NOT expose message content in notification
- Returns same generic chat notification object from Phase 1
- Reuses localization keys from Phase 1

#### 2.3 Import p2pUnwrap in background service

Ensure the `p2pUnwrap` extension method is accessible from the background isolate context (verify NostrEvent extensions are available without Riverpod).

**Files to modify:**
- `lib/features/notifications/services/background_notification_service.dart`

**Tests:**
- Unit test: verify sharedKey matching when tradeKey match fails
- Unit test: verify p2pUnwrap path produces generic notification

---

### Phase 3: In-App Notifications (Foreground, Outside Chat Screen)

**Scope:** When the user is in the app but NOT on the specific chat screen, show a temporary in-app notification (toast/snackbar).

**Design decisions:**
- Use existing `NotificationsNotifier.showCustomMessage()` for the toast
- Use existing `NotificationsNotifier.addToHistory()` for persistence (with new `Action.sendDm` or a dedicated chat notification type)
- Check if the relevant chat screen is currently active before showing

#### 3.1 Add chat event listener in order event processing

The `SubscriptionManager` already routes chat events to the `_chatController` stream. Currently only `ChatRoomNotifier` instances listen to this stream. We need a second listener that handles "no active chat screen" cases.

**Option A (Recommended):** Add a chat notification listener in the app initialization that listens to `subscriptionManagerProvider.chat` stream:

```dart
// In app_initializer or a dedicated provider
subscriptionManager.chat.listen((event) {
  // Find which session this belongs to
  final session = _findSessionBySharedKey(event.recipient, sessions);
  if (session == null) return;

  // Check if ChatRoomNotifier for this orderId is currently active
  final isChatScreenActive = _isChatRoomActive(session.orderId);
  if (isChatScreenActive) return; // Chat screen handles it

  // Show in-app notification
  notificationsNotifier.showCustomMessage(localizedChatMessage);
});
```

**Option B:** Add the logic inside `SubscriptionManager._handleEvent()` for chat type — but this couples notification logic into subscription management.

#### 3.2 Add similar listener for dispute chat events

Dispute chat events arrive on the `orders` stream (same `tradeKey.public`). The existing order processing in `AbstractMostroNotifier.handleEvent()` already processes these. We need to detect the DM format there and trigger a notification when the dispute chat screen is not active.

#### 3.3 Determine "chat screen active" state

Add a simple mechanism to track if a specific chat screen is open:
- `ChatRoomNotifier` sets a flag on creation, clears on dispose
- Or use a simple `Set<String>` of active orderId chat screens in a provider
- Check this set before showing notification

**Files to modify:**
- New file: `lib/features/chat/providers/chat_notification_listener.dart` (or add to existing provider)
- `lib/features/notifications/notifiers/notifications_notifier.dart` — possibly add chat-specific method
- `lib/core/app_initializer.dart` or equivalent — wire up the listener
- `lib/features/chat/notifiers/chat_room_notifier.dart` — expose "active" state
- `lib/features/disputes/notifiers/dispute_chat_notifier.dart` — expose "active" state
- `lib/l10n/intl_*.arb` — add in-app notification strings if different from background ones

**Tests:**
- Unit test: verify notification shown when chat screen is NOT active
- Unit test: verify notification NOT shown when chat screen IS active
- Unit test: verify dispute chat notifications trigger correctly

---

### Phase 4: Push/FCM for P2P Chat (App Killed)

**Scope:** When the app is completely killed, P2P chat messages should wake the app via FCM.

**Problem:** Push server monitors relays for `tradeKey.public` in the `p` tag. P2P chat events use `sharedKey.public` — the push server doesn't know about these keys and cannot decrypt or match them.

**Solution: Sender-triggered notification**

When User A sends a P2P chat message to User B:
1. Publish encrypted event to relay (existing)
2. Call push server: `POST /api/notify { "trade_pubkey": "<peer's tradeKey.public>" }`

This works because:
- User A knows `session.peer.publicKey` (the counterparty's trade pubkey)
- The push server already has User B's `tradeKey → FCM token` mapping
- No new data revealed — push server already knows the trade pubkey
- No message content transmitted — just a "wake up" signal
- Push server doesn't learn the sharedKey ↔ tradeKey relationship

**Why this approach vs registering sharedKey:**
- No additional pubkey registration needed
- Push server doesn't learn the sharedKey ↔ tradeKey relationship
- Simpler server-side implementation
- Same privacy guarantees as existing Mostro event notifications

#### 4.1 Add `notifyPeer()` to `PushNotificationService`

```dart
Future<bool> notifyPeer(String peerTradePubkey) async {
  final response = await http.post(
    Uri.parse('$_pushServerUrl/api/notify'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'trade_pubkey': peerTradePubkey}),
  ).timeout(const Duration(seconds: 10));
  return response.statusCode == 200;
}
```

#### 4.2 Call `notifyPeer()` after sending P2P chat message

In `ChatRoomNotifier.sendMessage()`, after successful `publishEvent()`:

```dart
// After publishing the wrapped event
final pushService = ref.read(pushNotificationServiceProvider);
pushService.notifyPeer(session.peer!.publicKey);
```

Fire-and-forget (don't block on the response, don't fail the send if push fails).

#### 4.3 Push server changes (external)

New endpoint needed on the push server:

```
POST /api/notify
Body: { "trade_pubkey": "<64-char hex>" }
Response: 200 OK | 404 (pubkey not registered)
```

Simply sends a silent FCM notification to the device registered for that trade pubkey. Same behavior as relay-monitored events, but triggered on-demand.

**Consideration:** Rate limiting on `/api/notify` to prevent abuse (e.g., max 10 calls per trade_pubkey per minute).

#### 4.4 Admin/Dispute Chat Push — Verify existing coverage

Admin events already use `tradeKey.public` as the `p` tag. The push server's relay monitoring should already cover these. Verify this works end-to-end. If not, add `notifyPeer()` call in `DisputeChatNotifier.sendMessage()` as well.

**Files to modify:**
- `lib/services/push_notification_service.dart` — add `notifyPeer()` method
- `lib/features/chat/notifiers/chat_room_notifier.dart` — call `notifyPeer()` after send
- `lib/features/disputes/notifiers/dispute_chat_notifier.dart` — call `notifyPeer()` if needed
- Push server repository (external) — add `/api/notify` endpoint

**Tests:**
- Unit test: verify `notifyPeer()` makes correct HTTP call
- Unit test: verify `sendMessage()` calls `notifyPeer()` after publish
- Integration test: end-to-end P2P message → FCM wake → background notification

---

## Phase Summary

| Phase | Scope | Complexity | Files Changed | Server Changes |
|-------|-------|-----------|---------------|----------------|
| 1 | Admin DM background notifications | Low | 4 | None |
| 2 | P2P chat background notifications | Low-Medium | 1 | None |
| 3 | In-app notifications (foreground) | Medium | 5-6 | None |
| 4 | Push/FCM for P2P chat (app killed) | Medium | 3-4 | New endpoint |

## Privacy Considerations

- No message content ever leaves the device unencrypted
- All notifications show generic text: "New message in your trade"
- FCM only receives silent/empty notifications (no data payload)
- Push server only knows `tradeKey → device token` mapping (already existing)
- The `/api/notify` endpoint doesn't reveal sender identity
- Shared keys are never registered or transmitted to any server
- All decryption happens locally on-device
- Future: message preview could be a user setting (content stays on device)

## Open Questions

1. **Notification grouping:** Should chat notifications be grouped separately from trade notifications? Currently all use tag `mostro-trade` with fixed ID 0 (replaces previous notification). Chat notifications might warrant a separate channel/group so they don't replace trade-critical notifications.

2. **Badge count:** Should chat messages contribute to an unread badge on the chat tab / bottom nav? This would require tracking unread state per chat session.

3. **Notification tap action:** Should tapping a chat notification navigate to the specific chat room or to the notifications screen? Current trade notifications go to `/notifications`.

4. **Rate limiting for Phase 4:** Exact rate limits for `/api/notify` — needs coordination with push server maintainers.

5. **Dispute chat push verification:** Need to confirm whether the push server's relay monitoring already catches admin DM events targeting `tradeKey.public`, or if explicit notify calls are needed.
