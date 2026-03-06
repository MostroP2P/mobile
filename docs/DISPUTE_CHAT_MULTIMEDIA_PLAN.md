# Dispute Chat Multimedia Architecture

> Technical documentation for the dispute chat system: shared key encryption, multimedia support, and code sharing with P2P chat.

## Overview

The app has two chat systems that share encryption, upload, and rendering infrastructure:

| | P2P Chat (User-User) | Dispute Chat (User-Admin) |
|-|----------------------|--------------------------|
| **Encryption** | `p2pWrap()` with ECDH shared key | `p2pWrap()` with admin ECDH shared key |
| **Key field** | `session.sharedKey` | `session.adminSharedKey` |
| **Routing (`p` tag)** | Shared key pubkey | Admin shared key pubkey |
| **Message model** | `NostrEvent` | `DisputeChatMessage(NostrEvent)` with pending/error state |
| **Storage** | Gift wrap events (encrypted) on disk | Gift wrap events (encrypted) on disk |
| **Multimedia** | Images + files via Blossom | Images + files via Blossom |
| **Notifier** | `ChatRoomNotifier` | `DisputeChatNotifier` |
| **Message bubble** | `MessageBubble` | `DisputeMessageBubble` |
| **Input widget** | `MessageInput` | `DisputeMessageInput` |

## Encryption

Both chats use NIP-59 gift wrap with 1-layer `p2pWrap`/`p2pUnwrap`:

1. **Key computation:** `ECDH(tradeKey.private, peerPubkey)` produces a shared key
2. **Sending:** Inner event (kind 1, plain text or JSON) wrapped via `p2pWrap(tradeKey, sharedKey.public)`
3. **Receiving:** Gift wrap (kind 1059) unwrapped via `event.p2pUnwrap(sharedKey)`
4. **Storage:** Gift wrap event stored encrypted on disk; unwrapped on load

For disputes, the "peer" is the admin. The shared key is computed when the admin takes the dispute (`session.setAdminPeer(adminPubkey)`). A session can have both `sharedKey` (P2P peer) and `adminSharedKey` (admin) simultaneously.

## Multimedia Pipeline

### Upload flow (sending)

Both input widgets delegate to `ChatFileUploadHelper.selectAndUploadFile()`:

```
User taps attach -> File picker -> Size check -> Confirmation dialog
-> MIME detection -> Encrypt (ChaCha20-Poly1305) -> Upload to Blossom
-> Send JSON metadata as chat message
```

**Key file:** `lib/shared/utils/chat_file_upload_helper.dart`

The helper accepts callbacks (`getSharedKey`, `sendMessage`, `isMounted`) so it works with both P2P and dispute chat without any provider coupling.

### Download flow (receiving)

When a message arrives, `_processMessageContent()` in each notifier detects JSON content and pre-downloads media:

- **Images:** Downloaded, decrypted, cached immediately for inline display
- **Files (image type):** Same as images — auto-downloaded for preview
- **Files (non-image):** Only metadata cached; user triggers download manually

### Rendering

`EncryptedImageMessage` and `EncryptedFileMessage` widgets are provider-agnostic. They accept callbacks:

```dart
EncryptedImageMessage(
  message: nostrEvent,
  isOwnMessage: bool,
  getSharedKey: () => Future<Uint8List>,
  getCachedImage: (messageId) => Uint8List?,
  getImageMetadata: (messageId) => EncryptedImageUploadResult?,
  cacheDecryptedImage: (messageId, data, meta) => void,
)
```

Each bubble widget (`MessageBubble`, `DisputeMessageBubble`) passes its notifier's methods as callbacks.

## Shared Infrastructure

### `MediaCacheMixin` — `lib/shared/mixins/media_cache_mixin.dart`

In-memory cache for decrypted images and files. Used by both `ChatRoomNotifier` and `DisputeChatNotifier` via `with MediaCacheMixin`. Provides:

- `cacheDecryptedImage()` / `getCachedImage()` / `getImageMetadata()`
- `cacheDecryptedFile()` / `getCachedFile()` / `getFileMetadata()`
- `clearMediaCaches()` — must be called explicitly in each notifier's dispose

The mixin is intentionally unconstrained (no `on StateNotifier`) to support future Riverpod 3.x migration where `StateNotifier` is replaced by `Notifier`/`AsyncNotifier`.

### `NostrUtils.sharedKeyToBytes()` — `lib/shared/utils/nostr_utils.dart`

Converts a `NostrKeyPairs` shared key (64-char hex private key) to `Uint8List(32)` for ChaCha20-Poly1305 encryption. Used by both `getSharedKey()` and `getAdminSharedKey()`.

### `ChatFileUploadHelper` — `lib/shared/utils/chat_file_upload_helper.dart`

Static helper that handles the complete upload flow: file picker, size validation, confirmation dialog, MIME detection, encryption, Blossom upload, and error handling. Both `MessageInput` and `DisputeMessageInput` delegate to this helper.

### Upload/Download Services (stateless, decoupled)

| Service | Purpose |
|---------|---------|
| `EncryptedImageUploadService` | Encrypt + upload images; download + decrypt images |
| `EncryptedFileUploadService` | Encrypt + upload files; download + decrypt files |
| `BlossomUploadHelper` | Upload encrypted data to Blossom servers with retry |
| `EncryptionService` | ChaCha20-Poly1305 encrypt/decrypt |
| `MediaValidationService` | Image validation and sanitization |
| `FileValidationService` | File size/type validation |

### Message Type Detection — `lib/features/chat/utils/message_type_helpers.dart`

`MessageTypeUtils.getMessageType(event)` returns `MessageContentType.text`, `.encryptedImage`, or `.encryptedFile` by parsing the message JSON content.

## Key Files

### Dispute chat

| File | Purpose |
|------|---------|
| `lib/features/disputes/notifiers/dispute_chat_notifier.dart` | State management, encryption, storage, media processing |
| `lib/features/disputes/widgets/dispute_message_bubble.dart` | Message rendering with multimedia support |
| `lib/features/disputes/widgets/dispute_message_input.dart` | Text + file attachment input |
| `lib/features/disputes/widgets/dispute_messages_list.dart` | Scrollable message list |
| `lib/features/disputes/widgets/dispute_content.dart` | Chat screen layout |

### P2P chat

| File | Purpose |
|------|---------|
| `lib/features/chat/notifiers/chat_room_notifier.dart` | State management, encryption, storage, media processing |
| `lib/features/chat/widgets/message_bubble.dart` | Message rendering with multimedia support |
| `lib/features/chat/widgets/message_input.dart` | Text + file attachment input |
| `lib/features/chat/widgets/encrypted_image_message.dart` | Decoupled image download/decrypt/display widget |
| `lib/features/chat/widgets/encrypted_file_message.dart` | Decoupled file download/decrypt/display widget |

### Shared

| File | Purpose |
|------|---------|
| `lib/shared/mixins/media_cache_mixin.dart` | In-memory media cache mixin |
| `lib/shared/utils/chat_file_upload_helper.dart` | Shared file upload flow |
| `lib/shared/utils/nostr_utils.dart` | `sharedKeyToBytes()` and other crypto utilities |

## DisputeChatMessage Wrapper

Unlike P2P chat which uses raw `NostrEvent`, dispute chat wraps events in `DisputeChatMessage`:

```dart
class DisputeChatMessage {
  final NostrEvent event;
  final bool isPending;   // true while sending
  final String? error;    // per-message error (not global state error)
}
```

This provides optimistic UI (message appears immediately with pending indicator) and per-message error state without modifying `NostrEvent`.

## Known Issues

| Issue | Description |
|-------|-------------|
| P2P `await _processMessageContent` blocks rendering | `ChatRoomNotifier._onChatEvent()` awaits image download before showing message. Should use `unawaited()` like dispute chat does. |
| Service instances created per call | Both notifiers create new upload service instances on every `_processEncryptedImageMessage`/`_processEncryptedFileMessage` call. Should be static fields. |

---

*Last updated: 2026-03-06*
