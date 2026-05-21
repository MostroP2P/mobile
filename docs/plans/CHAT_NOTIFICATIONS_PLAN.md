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

### Phase 1: Admin/Dispute Chat Background Notifications (COMPLETED)

**Status:** Merged to main.

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
- `chat_notification_body`: "You have a new message in your trade" / "Tienes un nuevo mensaje en tu operación" / "Hai un nuovo messaggio nella tua operazione"

**Files to modify:**
- `lib/features/notifications/services/background_notification_service.dart`
- `lib/l10n/intl_en.arb`
- `lib/l10n/intl_es.arb`
- `lib/l10n/intl_it.arb`

**Tests:**
- Unit test: verify DM format detection in `_decryptAndProcessEvent` mock path
- Unit test: verify generic notification text generation

---

### Phase 2: P2P Chat Background Notifications (COMPLETE)

**Status:** Open PR, pending merge.

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

### Phase 3: In-App Notifications (Foreground, Outside Chat Screen) — (COMPLETE)

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

  // Show in-app notification using a string KEY (not pre-localized)
  // Following the existing pattern: showCustomMessage passes a key,
  // NotificationListenerWidget resolves it via S.of(context)
  notificationsNotifier.showCustomMessage('chatNewMessage');
});
```

**Important:** Follow the existing localization pattern — `showCustomMessage()` receives a **string key**, not a pre-localized string. The UI layer (`NotificationListenerWidget`) resolves the key to localized text via `S.of(context)!`. This is the same pattern used for `'orderTimeoutTaker'`, `'orderCanceled'`, etc.

Add the new key to `NotificationListenerWidget`'s switch:
```dart
case 'chatNewMessage':
  message = S.of(context)!.chat_notification_body;
  break;
```

And for dispute chat:
```dart
case 'disputeChatNewMessage':
  message = S.of(context)!.dispute_chat_notification_body;
  break;
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

### Phase 4: Push/FCM for P2P Chat (App Killed) — PENDING

**Scope:** When the app is completely killed, P2P chat messages should wake the app via FCM.

**Problem:** The push server's Nostr listener monitors relays for `kind 1059` events and looks up tokens by the `p` tag. P2P chat events use `sharedKey.public` as the `p` tag — the push server has no `sharedKey → token` mapping and cannot match them via the listener path.

**Solution: Sender-triggered notification via existing `/api/notify`**

The push server already exposes `POST /api/notify` (see `mostro-push-server/docs/api.md`). When User A sends a P2P chat message to User B:
1. Publish encrypted event to relay (existing).
2. Call `POST /api/notify { "trade_pubkey": "<peer's tradeKey.public>" }` — fire-and-forget.

This works because:
- User A knows `session.peer.publicKey` (the counterparty's trade pubkey).
- The push server already has User B's `tradeKey → FCM token` mapping.
- No new data revealed — the trade pubkey is the same identifier used in `/api/register`.
- No message content transmitted — only a "wake up" signal.
- Push server never learns the `sharedKey ↔ tradeKey` relationship.

**Why this approach vs registering `sharedKey`:**
- No additional pubkey registration needed.
- Push server doesn't learn the `sharedKey ↔ tradeKey` relationship.
- Simpler server-side implementation.
- Same privacy guarantees as existing Mostro event notifications.

#### 4.1 Add `notifyPeer()` to `PushNotificationService`

The endpoint is **strictly fire-and-forget** because of the privacy contract enforced server-side (see `mostro-push-server/CLAUDE.md` "Hard constraints"):

- Always `202 { "accepted": true }` on parse-valid input — registered vs unregistered pubkeys are **indistinguishable** (status, body, headers, timing). There is no `200`, no `404`.
- `400` only on JSON parse failure or invalid pubkey (64 hex chars).
- `429` on rate-limit hit. Body is **byte-identical** between per-IP and per-pubkey paths; clients cannot tell which limiter tripped. `Retry-After` header carries whole seconds (min 1).
- No `sender_pubkey`, no signature, no `Authorization` header, no `Idempotency-Key` — anything that would let the operator correlate sender and recipient is rejected at the boundary.
- Inbound `X-Request-Id` is stripped server-side; the response carries a server-generated UUIDv4.

Implementation:

```dart
Future<void> notifyPeer(String peerTradePubkey) async {
  try {
    final response = await http.post(
      Uri.parse('$_pushServerUrl/api/notify'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'trade_pubkey': peerTradePubkey}),
    ).timeout(const Duration(seconds: 5));

    // 202 = accepted (registered/unregistered indistinguishable by contract).
    // 400 = malformed pubkey -> client bug, log it.
    // 429 = rate-limited -> drop silently (fire-and-forget, no retry).
    if (response.statusCode == 400) {
      logger.w('notifyPeer: invalid pubkey rejected by server');
    }
  } catch (_) {
    // Network error / timeout: never fail the chat send because of this.
  }
}
```

No boolean return, no retry loop, no body parsing. The server contract makes any client-side branching on registration state both impossible and unwanted.

#### 4.2 Call `notifyPeer()` after sending P2P chat message

In `ChatRoomNotifier.sendMessage()`, immediately after `await publishEvent(wrappedEvent)` succeeds and **before** `eventStore.putItem()` so the wake-up does not depend on local persistence:

```dart
await ref.read(nostrServiceProvider).publishEvent(wrappedEvent);

// Fire-and-forget: wake the peer's device if registered.
unawaited(
  ref.read(pushNotificationServiceProvider).notifyPeer(session.peer!.publicKey),
);
```

Fire-and-forget — never block the send and never surface the result to the user.

#### 4.3 Push server side — already implemented, verify only

`POST /api/notify` is already deployed and documented in [`mostro-push-server/docs/api.md`](https://github.com/MostroP2P/mostro-push-server/blob/main/docs/api.md). No server changes are required for this phase. Quick verification checklist:

- [ ] `curl -i -X POST $SERVER/api/notify -H 'content-type: application/json' -d '{"trade_pubkey":"<64-hex>"}'` returns `202 {"accepted":true}`.
- [ ] Malformed pubkey returns `400`.
- [ ] Sustained traffic above the per-pubkey limit returns `429` with `Retry-After`.
- [ ] Response carries a server-generated `x-request-id`.

**Authentication model: intentionally unauthenticated (consistent with existing design)**

The existing `/api/register` endpoint is also unauthenticated. `/api/notify` follows the same model. Alternatives were considered and rejected:

- **Sender signature authentication** — rejected because it would reveal the sender's trade pubkey to the push server, breaking the privacy guarantee that the server doesn't learn who is messaging whom.
- **Registration-time counterparty binding** — rejected because it requires the push server to store counterparty relationships (`A trades with B`), which it currently doesn't know and shouldn't.

**Threat analysis for unauthenticated `/api/notify`:**

| Threat | Severity | Mitigation |
|--------|----------|------------|
| Data harvest / enumeration | None | Endpoint always returns `202` regardless of registration state. The 202/400/429 set leaks no information about which pubkeys are registered. |
| DoS / battery drain | Medium | Server-side rate limits already in place: per-`trade_pubkey` and per-IP limiters (`governor`); spawn pile capped at 50 permits; client is fire-and-forget with no retry on 429. |
| Unsolicited wake-ups | Low | FCM notifications are silent. The background service only processes events it can decrypt; spurious wake-ups are no-ops. OS battery optimization further limits impact. |

**Server-side rate limits (already configured, defaults):**
- Per-`trade_pubkey`: `30/min`, burst `10` (env `NOTIFY_RATE_PER_PUBKEY_PER_MIN`).
- Per-IP: `120/min`, burst `30` (env `NOTIFY_RATE_PER_IP_PER_MIN`).
- Both must allow the request; on 429 the body is byte-identical to prevent oracle behavior.

Client handles 429 by dropping the call silently — fire-and-forget on a chat send must never block, retry, or surface an error to the user.

#### 4.4 Admin/Dispute Chat Push — no `notifyPeer()` needed

Dispute chat is fully covered by the existing listener path; **no client-side `notifyPeer()` call is required**.

Why: admin DMs in disputes are sent user-to-user as `kind 1059` gift wraps, with `p = recipient's tradeKey.public`. The push server's listener (`src/nostr/listener.rs`) deliberately does **not** apply an `authors` filter — this is a hard constraint in `mostro-push-server/CLAUDE.md` precisely because Gift Wrap uses ephemeral outer keys and admin DMs are not Mostro-daemon-signed. So:

- **Admin → user:** kind 1059 hits the relay → listener picks it up by the `p` tag → token lookup against the user's registered `tradeKey` → silent FCM. Already works.
- **User → admin:** admins typically run desktop/CLI clients that are not registered with the push server. Out of scope for the mobile app.

The existing Phase 1 code path (DM payload detection in `_decryptAndProcessEvent`) handles the rendering once the device wakes. **Do not add `notifyPeer()` to `DisputeChatNotifier.sendMessage()`** — it would only serve to wake the sender's own counterpart in non-dispute scenarios and muddy the model.

#### 4.5 Align `/api/register` with the trusted-instance whitelist

Out-of-band but tightly adjacent: `mostro-push-server` v1.1 added an opt-in whitelist of trusted Mostro instance pubkeys. When `TRUSTED_WHITELIST_ENABLED=true` and the embedded list is non-empty, `/api/register` requires a `mostro_pubkey` field and rejects clients that omit it with `403 "Mostro instance pubkey required"`.

The flag currently defaults to `false`, so today's clients keep working. To avoid breakage when the operator flips it after the mobile rollout, this PR should add `mostro_pubkey` to the registration body.

```dart
body: jsonEncode({
  'trade_pubkey': tradePubkey,
  'token': fcmToken,
  'platform': _platform,
  'mostro_pubkey': selectedMostroNodePubkey, // 64-hex of active Mostro instance
}),
```

Source: `MostroNodesNotifier` / `selectedMostroNodeProvider` already tracks the active node. The field is request-only and does not affect response shape, so it is backwards-compatible with servers that ignore it.

**Files to modify:**
- `lib/services/push_notification_service.dart` — add `notifyPeer()`; add `mostro_pubkey` to `registerToken()` body.
- `lib/features/chat/notifiers/chat_room_notifier.dart` — fire-and-forget `notifyPeer()` after `publishEvent`.
- (No changes to `DisputeChatNotifier` — see 4.4.)
- (No changes to push server — already implemented.)

**Tests:**
- Unit test: `notifyPeer()` posts the expected body and never throws on `202`/`400`/`429`/network error.
- Unit test: `sendMessage()` invokes `notifyPeer()` exactly once after a successful `publishEvent`, and does not await it.
- Unit test: `registerToken()` includes `mostro_pubkey` in the request body.
- Manual / integration: end-to-end P2P message → FCM wake → background notification on a real device.

---

## Phase Summary

| Phase | Scope | Complexity | Files Changed | Server Changes |
|-------|-------|-----------|---------------|----------------|
| 1 | Admin DM background notifications | Low | 4 | None |
| 2 | P2P chat background notifications | Low-Medium | 1 | None |
| 3 | In-app notifications (foreground) | Medium | 5-6 | None |
| 4 | Push/FCM for P2P chat (app killed) + register whitelist alignment | Medium | 2 | None (`/api/notify` already deployed) |

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

4. ~~**Rate limiting for Phase 4:**~~ **Resolved:** server enforces `30/min` per `trade_pubkey` (burst 10) and `120/min` per IP (burst 30). Client is fire-and-forget with no retry on 429.

5. ~~**Dispute chat push verification:**~~ **Resolved:** the push-server listener has no `authors` filter (hard constraint), so admin DMs targeting `tradeKey.public` are caught by the listener path. No `notifyPeer()` call is needed for dispute chat.
