# P2P Chat System — Implementation Architecture

This document describes how the peer-to-peer chat between trading parties works at the implementation level: how events flow from relays to the UI, how messages are persisted, what is stored encrypted vs. in plaintext, and known issues that have been fixed.

For the **protocol specification** (ECDH, HKDF key derivation, event format), see the [Mostro P2P Chat protocol](https://mostro.network/protocol/chat.html) ([source](https://github.com/MostroP2P/protocol)).

> **Note:** P2P peer chat uses the spec's kind-14 chat envelope (`ChatKeys` +
> `chatWrap`/`chatUnwrap`), the same primitives as the **dispute chat** (see
> `DISPUTE_CHAT_KIND14.md`). The legacy 1-layer gift wrap (kind 1059) was fully
> replaced on the wire; `p2pUnwrap` remains only to read pre-migration history
> stored on disk.

---

## Components

| Component | File | Responsibility |
|---|---|---|
| `SubscriptionManager` | `lib/features/subscriptions/subscription_manager.dart` | Single Nostr subscription for all chats, broadcast stream |
| `ChatRoomNotifier` | `lib/features/chat/notifiers/chat_room_notifier.dart` | Per-order chat: receives events, stores to disk, decrypts, manages state |
| `ChatRoomsNotifier` | `lib/features/chat/notifiers/chat_rooms_notifier.dart` | Chat list: loads, refreshes, reloads all chats |
| `chatRoomsProvider` | `lib/features/chat/chat_room_provider.dart` | Riverpod family provider, creates and initializes `ChatRoomNotifier` |
| `EventStorage` | `lib/data/repositories/event_storage.dart` | Sembast store for encrypted chat envelopes |
| `Session` | `lib/data/models/session.dart` | Holds trade keys, peer info, computes shared key via ECDH |
| `ChatKeys` | `lib/shared/utils/chat_keys.dart` | HKDF derivation of K_conv / K_sign from the ECDH secret |
| `NostrEvent` extensions | `lib/data/models/nostr_event.dart` | `chatWrap()` / `chatUnwrap()` envelope; `p2pUnwrap()` for legacy stored history |
| `ChatCursorStore` | `lib/services/chat_cursor_store.dart` | Durable per-conversation `since` cursor (prefix `chat_since_`) |

---

## Message Flow: Receiving

```text
Relay
  │  kind 14 chat envelopes (NIP-44 encrypted, authored by K_sign)
  ▼
NostrService (WebSocket)
  │
  ▼
SubscriptionManager
  │  ONE subscription with ALL conversations' pub(K_sign) in a single NostrFilter
  │  Events dispatched via StreamController.broadcast()
  ▼
ChatRoomNotifier._onChatEvent()  (one listener per active chat)
  │
  ├─ 1. Check author matches this chat's pub(K_sign) → skip if not ours
  ├─ 2. Dedup: eventStore.hasItem(event.id) → skip if already stored
  ├─ 3. Store encrypted envelope to Sembast (kind 14, NIP-44 encrypted content)
  ├─ 4. chatUnwrap(chatKeys, peerChatAllowedSigners) → verified kind 1 inner event
  ├─ 5. Advance the persisted since cursor (only after acceptance)
  ├─ 6. Add to state.messages (in-memory only)
  └─ 7. Notify chat list to refresh
```

### Key detail: single subscription, multiple listeners

`SubscriptionManager` creates **one** relay subscription containing the K_sign authors of all active chats. The spec requires filtering by `authors`, never by `#p`: a `#p` filter would let any third party flood the subscription with junk events, since relays only verify that an event is signed by *its own* author.

```dart
// subscription_manager.dart — _createFilterForType()
NostrFilter(
  kinds: [14],
  authors: chatSessions
      .map((s) => ChatKeys.fromSharedKey(s.sharedKey!).sign.public)
      .toList(),  // ALL conversations in ONE filter
  since: chatSince,  // earliest persisted cursor (ChatCursorStore)
  limit: NostrEventExtensions.chatDefaultLimit,
);
```

The relay sends events for all chats through this single subscription. Events are dispatched via a `StreamController.broadcast()` to all `ChatRoomNotifier` instances. Each notifier checks the event's author against its own `pub(K_sign)` to determine if the event belongs to its chat.

---

## Message Flow: Sending

```text
User types message
  │
  ▼
ChatRoomNotifier.sendMessage(text)
  │
  ├─ 1. createChatRumor: kind 1 inner event signed with tradeKey,
  │     carrying a random `u` nonce tag (same-second identical texts
  │     still get distinct inner ids)
  ├─ 2. chatWrap(chatKeys) → kind 14 envelope
  │     - NIP-44 self-encryption under K_conv
  │     - Authored and signed by K_sign
  │     - Exactly one p-tag = pub(K_conv)
  │     - Outer timestamp equals the inner one (spec replay defense)
  ├─ 3. Publish wrapped event to relay
  ├─ 4. Persist wrapped event to Sembast (encrypted, kind 14)
  ├─ 5. Add inner event (plaintext) to state.messages for immediate UI display
  └─ 6. Notify chat list to refresh
```

Step 4 ensures sent messages survive app restarts even if the relay echo never arrives (e.g., connection drops after send). When the relay echo does arrive, `_onChatEvent` skips it via the `hasItem` dedup check.

---

## Storage: What Is on Disk

Events are stored in Sembast's `events` store as encrypted kind-14 envelopes (pre-migration history remains as kind-1059 gift wraps):

```dart
{
  'id': event.id,                    // event hash
  'created_at': <unix timestamp>,
  'kind': 14,                        // chat envelope (legacy history: 1059)
  'content': '<NIP-44 encrypted>',   // ciphertext — NOT readable without K_conv
  'pubkey': '<pub(K_sign)>',         // conversation signing key, stable per trade
  'sig': '<K_sign signature>',
  'tags': [['p', '<pub(K_conv)>']],
  'type': 'chat',                    // app metadata
  'order_id': '<orderId>',           // app metadata — links event to a specific trade
}
```

**Privacy properties:**
- The `content` field is NIP-44 encrypted under K_conv. Reading it requires the ECDH shared secret (or the derived K_conv).
- Neither `pubkey` (K_sign) nor the `p` tag (K_conv) is linkable to any party's trade or identity keys without the ECDH secret.
- Sender identity (trade pubkey) is inside the encrypted payload, authenticated by the inner signature.
- The `order_id` is app-internal metadata not present in the Nostr event itself.

**What is NOT on disk:**
- Plaintext message content
- Sender identity (trade pubkey is inside the encrypted payload)
- Any private keys

---

## Storage: What Is in Memory

`state.messages` holds decrypted `NostrEvent` objects (kind 1) in RAM:

```dart
// After chatUnwrap:
NostrEvent(
  kind: 1,
  content: "Let's reestablish the peer-to-peer nature of Bitcoin!",  // plaintext
  pubkey: "<sender's trade pubkey>",
  // ...
)
```

These exist **only in memory**. When the app closes, they are lost. On restart, `_loadHistoricalMessages()` reads the encrypted envelopes from Sembast and decrypts them again.

---

## Shared Key Lifecycle

The shared key is never stored directly. It is computed via ECDH every time a `Session` has a `peer`:

```dart
// session.dart
set peer(Peer? newPeer) {
  _peer = newPeer;
  _sharedKey = NostrUtils.computeSharedKey(
    tradeKey.private,
    newPeer.publicKey,
  );
}
```

On app restart:
1. `SessionNotifier.init()` loads sessions from Sembast (peer is persisted)
2. The `Session` constructor calls `computeSharedKey` with the persisted peer's public key
3. The shared key is available in memory — no separate storage needed

---

## Initialization Sequence

### App startup (`app_init_provider.dart`)

```text
1. NostrService.init()         → relay connections
2. KeyManager.init()           → crypto keys from secure storage
3. MostroNodes.init()          → node metadata
4. SessionNotifier.init()      → loads sessions from Sembast (sharedKey computed here)
5. SubscriptionManager created → subscribes to relay with all session keys
6. For each session with peer:
   └─ Read chatRoomsProvider(orderId) → creates ChatRoomNotifier
      └─ _initializeChatRoomSafely() [async]
         ├─ _loadHistoricalMessages() → reads encrypted events from disk, decrypts
         └─ subscribe() → listens to broadcast stream
```

### Chat room initialization (`chat_room_provider.dart`)

When `chatRoomsProvider(orderId)` is first read, it:
1. Creates a `ChatRoomNotifier` with empty messages
2. Calls `_initializeChatRoomSafely()` (async, fire-and-forget)
3. Returns the notifier immediately (messages may not be loaded yet)

`_initializeChatRoomSafely()` then:
1. Calls `notifier.initialize()` → loads history from disk + subscribes to stream
2. Marks `chatRoomInitializedProvider(chatId)` as true

### Reconnection (`lifecycle_manager.dart`)

When the app returns to foreground after losing connection:
1. `NostrService` reconnects to relays
2. `reloadAllChats()` is called
3. Each `ChatRoomNotifier.reload()`:
   - Cancels current stream listener
   - Reloads messages from disk (`_loadHistoricalMessages`)
   - Re-subscribes to broadcast stream

---

## Historical Loading (`_loadHistoricalMessages`)

```text
Sembast query: WHERE type = 'chat' AND order_id = orderId
  │
  ▼
For each stored event:
  ├─ Reconstruct NostrEvent from stored map
  ├─ kind 14 → chatUnwrap(chatKeys, peerChatAllowedSigners)
  ├─ kind 1059 (legacy, pre-migration) → verify p-tag matches
  │  sharedKey.public, then p2pUnwrap(sharedKey)
  └─ Add to historicalMessages list
  │
  ▼
Merge with existing state.messages, deduplicate by ID, sort by created_at
```

Decryption itself acts as a safety filter: even if an event were somehow stored with an incorrect `order_id`, it won't be displayed in the wrong chat because the conversation keys wouldn't match.

---

## Multimedia Messages

Text messages have plain string content. Multimedia messages use JSON content:

### Sending
1. File/image encrypted with ChaCha20-Poly1305 using shared key bytes
2. Uploaded to Blossom server (encrypted blob)
3. JSON metadata sent as message content: `{ "type": "image_encrypted", "blossomUrl": "...", ... }`
4. The JSON is inside the NIP-44 chat envelope — doubly encrypted

### Receiving
1. Envelope arrives → decrypted to kind 1 → JSON content detected
2. `_processMessageContent()` identifies `image_encrypted` / `file_encrypted`
3. Downloads encrypted blob from Blossom, decrypts with shared key
4. Caches decrypted media in memory (`MediaCacheMixin`)

**Disk**: Only the encrypted envelope is stored (Blossom URL inside encrypted payload). Attachment encryption keys off the raw ECDH secret bytes, not K_conv/K_sign, so attachments are wire-compatible with other clients.
**Memory**: Decrypted media cached for display, cleared on dispose.

---

## Bug: Message Loss After Reconnection

### Symptom

With 2+ active trades, counterpart messages disappear after closing and reopening the app. Restoring the user brings them back.

### Root causes found and fixed

#### 1. Broadcast stream race condition (primary cause)

**Problem**: All `ChatRoomNotifier` instances listen to the same broadcast stream. When an event arrives, every notifier receives it. Before the fix, `_onChatEvent` stored the event to disk with its own `orderId` **before** checking the `p` tag to verify ownership. With multiple concurrent notifiers:

- Notifier A stores event with `order_id: "orderA"` (wrong)
- Notifier B stores same event with `order_id: "orderB"` (correct)
- Sembast upserts — last writer wins
- If A writes last, the event has the wrong `order_id` on disk
- On restart, notifier B queries `WHERE order_id = "orderB"` — doesn't find it

**Fix**: Verify the `p` tag matches `session.sharedKey.public` **before** any disk write. Only the owning notifier stores the event.

#### 2. Double subscription per chat

**Problem**: `app_init_provider.dart` explicitly called `subscribe()` on each `ChatRoomNotifier`, but creating the provider already triggers `_initializeChatRoomSafely()` → `initialize()` → `subscribe()`. This resulted in 2 listeners per chat on the broadcast stream, doubling disk write contention.

**Fix**: Removed the explicit `subscribe()` call from `app_init_provider.dart`. The provider's initialization handles subscription.

#### 3. Chat list empty after async initialization

**Problem**: `ChatRoomsNotifier.loadChats()` filters chats by `messages.isNotEmpty`, but `ChatRoomNotifier` initialization is async. When `loadChats()` runs, messages haven't loaded yet → all chats filtered out. No code called `refreshChatList()` after initialization completed.

**Fix**: `_initializeChatRoomSafely()` calls `refreshChatList()` after successful initialization.

#### 4. `reloadAllChats()` operates on empty state

**Problem**: `reloadAllChats()` iterates over `state` (the current chat list). If `state` is empty due to issue #3, nothing gets reloaded.

**Fix**: `reloadAllChats()` iterates over sessions (source of truth) instead of `state`.

#### 5. Sent messages not persisted (pre-existing)

**Problem**: `sendMessage()` only published to the relay and added to in-memory state. If the relay echo never arrived (connection drop), the sent message was lost on restart.

**Fix**: `sendMessage()` persists the wrapped event to Sembast immediately after successful publish.

#### 6. `reload()` didn't load from disk (pre-existing)

**Problem**: `reload()` only cancelled and re-subscribed to the stream. It didn't call `_loadHistoricalMessages()`, so reconnection couldn't recover messages from disk.

**Fix**: `reload()` calls `_loadHistoricalMessages()` before re-subscribing.

---

## File Reference

| File | Role |
|---|---|
| `lib/features/subscriptions/subscription_manager.dart` | Single subscription, broadcast stream, filter construction |
| `lib/features/chat/notifiers/chat_room_notifier.dart` | Per-chat event handling, storage, decryption, message state |
| `lib/features/chat/notifiers/chat_rooms_notifier.dart` | Chat list management, loadChats, refreshChatList, reloadAllChats |
| `lib/features/chat/chat_room_provider.dart` | Provider creation, async initialization |
| `lib/shared/providers/app_init_provider.dart` | App startup sequence, chat subscription setup |
| `lib/data/repositories/event_storage.dart` | Sembast wrapper for event persistence |
| `lib/data/models/session.dart` | Session model, ECDH shared key computation, peerChatAllowedSigners |
| `lib/data/models/nostr_event.dart` | createChatRumor / chatWrap / chatUnwrap; p2pUnwrap for legacy history |
| `lib/shared/utils/chat_keys.dart` | HKDF derivation of K_conv / K_sign |
| `lib/services/chat_cursor_store.dart` | Durable per-conversation since cursor |
| `lib/services/lifecycle_manager.dart` | Foreground/background transitions, chat reload |

---

*Last Updated: August 2026*
