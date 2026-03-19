# P2P Chat System — Implementation Architecture

This document describes how the peer-to-peer chat between trading parties works at the implementation level: how events flow from relays to the UI, how messages are persisted, what is stored encrypted vs. in plaintext, and known issues that have been fixed.

For the **protocol specification** (NIP-59, ECDH, event format), see the [Mostro P2P Chat protocol](https://mostro.network/protocol/chat.html) ([source](https://github.com/MostroP2P/protocol)).

---

## Components

| Component | File | Responsibility |
|---|---|---|
| `SubscriptionManager` | `lib/features/subscriptions/subscription_manager.dart` | Single Nostr subscription for all chats, broadcast stream |
| `ChatRoomNotifier` | `lib/features/chat/notifiers/chat_room_notifier.dart` | Per-order chat: receives events, stores to disk, decrypts, manages state |
| `ChatRoomsNotifier` | `lib/features/chat/notifiers/chat_rooms_notifier.dart` | Chat list: loads, refreshes, reloads all chats |
| `chatRoomsProvider` | `lib/features/chat/chat_room_provider.dart` | Riverpod family provider, creates and initializes `ChatRoomNotifier` |
| `EventStorage` | `lib/data/repositories/event_storage.dart` | Sembast store for gift wrap events |
| `Session` | `lib/data/models/session.dart` | Holds trade keys, peer info, computes shared key via ECDH |
| `NostrEvent` extensions | `lib/data/models/nostr_event.dart` | `p2pWrap()` / `p2pUnwrap()` — encrypt/decrypt gift wraps |

---

## Message Flow: Receiving

```text
Relay
  │  kind 1059 gift wrap events (encrypted)
  ▼
NostrService (WebSocket)
  │
  ▼
SubscriptionManager
  │  ONE subscription with ALL sharedKey pubkeys in a single NostrFilter
  │  Events dispatched via StreamController.broadcast()
  ▼
ChatRoomNotifier._onChatEvent()  (one listener per active chat)
  │
  ├─ 1. Check p-tag matches this chat's sharedKey.public → skip if not ours
  ├─ 2. Dedup: eventStore.hasItem(event.id) → skip if already stored
  ├─ 3. Store encrypted gift wrap to Sembast (kind 1059, NIP-44 encrypted content)
  ├─ 4. Decrypt: event.p2pUnwrap(sharedKey) → plaintext kind 1 event
  ├─ 5. Add to state.messages (in-memory only)
  └─ 6. Notify chat list to refresh
```

### Key detail: single subscription, multiple listeners

`SubscriptionManager` creates **one** relay subscription containing all active chat shared key pubkeys:

```dart
// subscription_manager.dart — _createFilterForType()
NostrFilter(
  kinds: [1059],
  p: sessions
      .where((s) => s.sharedKey?.public != null)
      .map((s) => s.sharedKey!.public)
      .toList(),  // ALL shared keys in ONE filter
);
```

The relay sends events for all chats through this single subscription. Events are dispatched via a `StreamController.broadcast()` to all `ChatRoomNotifier` instances. Each notifier checks the event's `p` tag to determine if the event belongs to its chat.

---

## Message Flow: Sending

```text
User types message
  │
  ▼
ChatRoomNotifier.sendMessage(text)
  │
  ├─ 1. Create kind 1 inner event, signed with tradeKey
  ├─ 2. p2pWrap(tradeKey, sharedKey.public) → kind 1059 gift wrap
  │     - Generates ephemeral key pair (single-use)
  │     - Encrypts inner event JSON with NIP-44 (ephemeral private + shared pubkey)
  │     - p-tag = sharedKey.public
  │     - Timestamp randomized to prevent time analysis
  ├─ 3. Publish wrapped event to relay
  ├─ 4. Persist wrapped event to Sembast (encrypted, kind 1059)
  ├─ 5. Add inner event (plaintext) to state.messages for immediate UI display
  └─ 6. Notify chat list to refresh
```

Step 4 ensures sent messages survive app restarts even if the relay echo never arrives (e.g., connection drops after send). When the relay echo does arrive, `_onChatEvent` skips it via the `hasItem` dedup check.

---

## Storage: What Is on Disk

Events are stored in Sembast's `events` store as encrypted gift wraps:

```dart
{
  'id': event.id,                    // event hash
  'created_at': <unix timestamp>,
  'kind': 1059,                      // gift wrap
  'content': '<NIP-44 encrypted>',   // ciphertext — NOT readable without private key
  'pubkey': '<ephemeral pubkey>',    // single-use key, does not identify the sender
  'sig': '<ephemeral signature>',
  'tags': [['p', '<sharedKey.public>']],
  'type': 'chat',                    // app metadata
  'order_id': '<orderId>',           // app metadata — links event to a specific trade
}
```

**Privacy properties:**
- The `content` field is NIP-44 encrypted. Reading it requires the ECDH shared key's private component.
- The `pubkey` is an ephemeral key generated per message. It does not identify the sender.
- The `p` tag contains the shared key's public component, not any party's real identity.
- The `order_id` is app-internal metadata not present in the Nostr event itself.

**What is NOT on disk:**
- Plaintext message content
- Sender identity (trade pubkey is inside the encrypted payload)
- Any private keys

---

## Storage: What Is in Memory

`state.messages` holds decrypted `NostrEvent` objects (kind 1) in RAM:

```dart
// After p2pUnwrap:
NostrEvent(
  kind: 1,
  content: "Let's reestablish the peer-to-peer nature of Bitcoin!",  // plaintext
  pubkey: "<sender's trade pubkey>",
  // ...
)
```

These exist **only in memory**. When the app closes, they are lost. On restart, `_loadHistoricalMessages()` reads the encrypted gift wraps from Sembast and decrypts them again.

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
  ├─ Verify p-tag matches session.sharedKey.public
  ├─ p2pUnwrap(sharedKey) → decrypt to kind 1 inner event
  └─ Add to historicalMessages list
  │
  ▼
Merge with existing state.messages, deduplicate by ID, sort by created_at
```

The p-tag check during loading (line 353) acts as a safety filter: even if an event was somehow stored with an incorrect `order_id`, it won't be displayed in the wrong chat because the decryption key wouldn't match.

---

## Multimedia Messages

Text messages have plain string content. Multimedia messages use JSON content:

### Sending
1. File/image encrypted with ChaCha20-Poly1305 using shared key bytes
2. Uploaded to Blossom server (encrypted blob)
3. JSON metadata sent as message content: `{ "type": "image_encrypted", "blossomUrl": "...", ... }`
4. The JSON is inside the NIP-44 gift wrap — doubly encrypted

### Receiving
1. Gift wrap arrives → decrypted to kind 1 → JSON content detected
2. `_processMessageContent()` identifies `image_encrypted` / `file_encrypted`
3. Downloads encrypted blob from Blossom, decrypts with shared key
4. Caches decrypted media in memory (`MediaCacheMixin`)

**Disk**: Only the gift wrap is stored (Blossom URL inside encrypted payload).
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
| `lib/data/models/session.dart` | Session model, ECDH shared key computation |
| `lib/data/models/nostr_event.dart` | p2pWrap / p2pUnwrap encryption/decryption |
| `lib/services/lifecycle_manager.dart` | Foreground/background transitions, chat reload |

---

*Last Updated: March 2026*
