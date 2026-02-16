# Dispute Chat: Shared Key + Multimedia Implementation Plan

> Technical roadmap for migrating the user-admin dispute chat from direct gift wrap to shared key encryption, and adding multimedia support via Blossom servers.

## Context

Currently the app has two completely different chat mechanisms:

| | P2P Chat (User-User) | Dispute Chat (User-Admin) |
|-|----------------------|--------------------------|
| **Wrap** | `p2pWrap()` — 1 layer | `mostroWrap()` — 3 layers (Rumor→Seal→Wrap) |
| **Key** | Shared key (ECDH) | Admin pubkey (direct) |
| **Routing (`p` tag)** | Shared key pubkey | Trade key / Admin pubkey |
| **Subscription** | `SubscriptionManager.chat` | Independent subscription |
| **Message model** | `NostrEvent` | `DisputeChat` (plain String) |
| **Content format** | Plain text / JSON | MostroMessage JSON |
| **Multimedia** | Images + files via Blossom | Not supported |
| **Message bubble** | `MessageBubble` (routes text/image/file) | `DisputeMessageBubble` (text only) |
| **Input widget** | `MessageInput` (text + attachment) | `DisputeMessageInput` (text only) |

**Goal:** Unify both chats to use the same shared key mechanism and enable multimedia in dispute chat, maximizing code reuse and eliminating redundancy.

---

## Phase 1: Shared Key for Dispute Chat (Protocol Change)
**Status:** `TODO`
**PR scope:** Core encryption/protocol change — no UI changes

### What you can test after this phase

> **First visible milestone:** You can open a dispute, the admin takes it, and you exchange **text messages** using the new shared key mechanism. This is the moment you confirm end-to-end communication works with the admin dev.

**Manual testing checklist:**
- [ ] Open a dispute on an active order
- [ ] Admin takes the dispute (you should see the admin assignment notification)
- [ ] Send a text message to the admin — admin receives and can read it
- [ ] Admin sends a text message back — you receive and can read it
- [ ] Send multiple messages back and forth — conversation flows correctly
- [ ] Close and reopen the app — historical messages load and display correctly
- [ ] Verify the orders subscription does NOT receive dispute chat messages (check logs)
- [ ] Open a regular P2P chat while a dispute is active — both work independently

### 1.1 Compute shared key with admin in `Session`

**File:** `lib/data/models/session.dart`

- Add an `adminSharedKey` field (type `NostrKeyPairs?`) to `Session`
- When admin pubkey arrives, compute: `ECDH(tradeKey.private, adminPubkey)` using existing `NostrUtils.computeSharedKey()`
- Add a setter/method like `setAdminPeer(String adminPubkey)` that computes and stores the admin shared key
- The admin side computes the same: `ECDH(adminKey.private, tradeKey.public)`

**Key decision:** Use a separate field (`adminSharedKey`) rather than overloading `sharedKey` (which is for the P2P peer). A session can have both a peer shared key AND an admin shared key simultaneously during a dispute.

### 1.2 Trigger shared key computation when admin is assigned

**File:** `lib/features/order/models/order_state.dart`

- In the `Action.adminTookDispute` handler (lines ~159-175), after extracting `adminPubkey`, call `session.setAdminPeer(adminPubkey)` to compute the admin shared key
- Ensure the session is updated/persisted with the new key

### 1.3 Change `DisputeChatNotifier` to use `p2pWrap`/`p2pUnwrap`

**File:** `lib/features/disputes/notifiers/dispute_chat_notifier.dart`

**Sending (method `sendMessage`):**
- Replace `mostroWrap(session.tradeKey, dispute.adminPubkey!)` with `p2pWrap(session.tradeKey, session.adminSharedKey!.public)`
- Change content from MostroMessage JSON format to plain text (just the message string)
- Inner event: kind 1, signed by trade key, `p` tag = admin shared key pubkey

**Receiving (method `_onChatEvent`):**
- Replace `event.mostroUnWrap(session.tradeKey)` with `event.p2pUnwrap(session.adminSharedKey!)`
- Add `p` tag verification: check `pTag[1] == session.adminSharedKey!.public` (same as P2P chat does)
- Simplify content parsing: read `unwrappedEvent.content` directly as text instead of parsing MostroMessage JSON

### 1.4 Update subscription to use admin shared key

**File:** `lib/features/disputes/notifiers/dispute_chat_notifier.dart`

- Change the subscription filter from `p: [session.tradeKey.public]` to `p: [session.adminSharedKey!.public]`
- This eliminates the collision with the orders subscription (which also filters by trade key public)
- Remove the "dm" skip logic from `MostroService._onData()` (`lib/services/mostro_service.dart:130-135`) since dispute messages will no longer arrive on the orders stream

**Alternative (better):** Integrate dispute chat into `SubscriptionManager` by adding admin shared key pubkeys to the chat filter. This would unify all chat subscriptions.

### 1.5 Tests to create

**File:** `test/features/disputes/dispute_shared_key_test.dart`

```
group('Dispute Shared Key Computation')
  test('computes identical shared key from both sides (user and admin)')
    - Derive two key pairs (simulate user trade key and admin key)
    - Compute ECDH from both directions
    - Assert both produce the same shared secret

  test('admin shared key is independent from peer shared key')
    - Create a session with a peer (P2P shared key)
    - Set admin peer (admin shared key)
    - Assert both keys exist and are different

  test('admin shared key is null when no admin assigned')
    - Create a session without admin
    - Assert adminSharedKey is null
```

**File:** `test/data/models/nostr_event_wrap_test.dart`

```
group('p2pWrap / p2pUnwrap round-trip')
  test('wraps and unwraps a text message correctly')
    - Create a kind 1 inner event with known content
    - Wrap with p2pWrap using sender keys + shared key pubkey
    - Unwrap with p2pUnwrap using the shared key
    - Assert content matches, sender pubkey matches

  test('unwrap fails with wrong key')
    - Wrap a message
    - Try to unwrap with a different key pair
    - Assert throws exception

  test('wrapped event has kind 1059 and correct p tag')
    - Wrap a message
    - Assert wrapper kind == 1059
    - Assert p tag == shared key pubkey
    - Assert wrapper pubkey != sender pubkey (ephemeral)
```

**Pattern to follow:** Use real crypto keys via `KeyDerivator` with a test mnemonic (same pattern as `mostro_service_test.dart` and `file_messaging_test.dart`).

### 1.6 Coordinate with admin dev

The admin/solver needs to implement the counterpart:
- Compute `ECDH(adminKey.private, userTradeKey.public)` to get the same shared key
- Subscribe to kind 1059 events with `p` tag = shared key pubkey
- Use `p2pUnwrap(sharedKey)` to decrypt (1 layer, not 2)
- Use `p2pWrap(adminKey, sharedKey.public)` to send
- Content is plain text (no MostroMessage JSON wrapper)

---

## Phase 2: Unify Message Model
**Status:** `TODO`
**PR scope:** Internal refactor — model and notifier changes, no visible UI change
**Depends on:** Phase 1 completed

### What you can test after this phase

> **No visible change from the user's perspective.** The dispute chat should look and behave exactly the same as after Phase 1. This is a pure internal refactor.

**Manual testing checklist (regression):**
- [ ] All Phase 1 tests still pass — send/receive text messages works
- [ ] Pending indicator shows while message is being sent
- [ ] Error state shows if sending fails (test by disabling network)
- [ ] Historical messages load correctly after app restart
- [ ] Message ordering is correct (oldest to newest)
- [ ] No duplicate messages appear

### 2.1 Migrate `DisputeChatNotifier` to use `NostrEvent` as message model

**Current state:** `DisputeChatState` holds `List<DisputeChat>` where `DisputeChat` has a plain `String message`.

**Target state:** `DisputeChatState` holds `List<NostrEvent>` — same as `ChatRoomNotifier`.

**File:** `lib/features/disputes/notifiers/dispute_chat_notifier.dart`

- Change `DisputeChatState.messages` from `List<DisputeChat>` to `List<NostrEvent>`
- In `_onChatEvent()`: after `p2pUnwrap()`, store the unwrapped `NostrEvent` directly (it already contains content, pubkey, timestamp, id)
- In `sendMessage()`: after creating the inner event, add it to state directly as `NostrEvent` (optimistic UI)
- `isFromUser` determination: compare `unwrappedEvent.pubkey` with `session.tradeKey.public`
- Keep pending/error handling by wrapping in a separate mechanism or using event metadata

### 2.2 Handle pending/error state for sent messages

The current `DisputeChat` model has `isPending` and `error` fields. Since `NostrEvent` doesn't have these, we need a lightweight solution:

- Option A: Maintain a `Set<String> _pendingIds` and `Map<String, String> _errorMessages` in the notifier
- Option B: Create a thin wrapper `DisputeChatMessage { NostrEvent event; bool isPending; String? error; }`

**Recommended:** Option B — keeps it clean and self-contained. The wrapper is minimal and only exists for dispute-specific UI needs (pending indicator, error state).

### 2.3 Update storage format

**File:** `lib/features/disputes/notifiers/dispute_chat_notifier.dart`

- Store complete event data (kind, content, pubkey, sig, tags) so events can be reconstructed and re-unwrapped on historical load
- Store the raw gift wrap event (like P2P chat does) rather than the unwrapped content
- On historical load, reconstruct and unwrap events the same way P2P chat does in `_loadHistoricalMessages()`

### 2.4 Add `getSharedKey()` method to `DisputeChatNotifier`

```dart
Future<Uint8List> getAdminSharedKey() async {
  final session = _getSessionForDispute();
  final hexKey = session!.adminSharedKey!.private;
  final bytes = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    bytes[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
```

This is identical to `ChatRoomNotifier.getSharedKey()` — consider extracting to a shared utility.

### 2.5 Tests to create

**File:** `test/features/disputes/dispute_chat_notifier_test.dart`

```
group('DisputeChatNotifier message model')
  test('stores unwrapped NostrEvent after receiving message')
    - Mock a gift wrap event arriving
    - Verify state contains a NostrEvent with correct content

  test('sent message appears in state as NostrEvent with isPending')
    - Call sendMessage('hello')
    - Verify state has a message wrapper with isPending=true
    - After publish completes, verify isPending=false

  test('error state is captured on publish failure')
    - Mock nostrService.publishEvent to throw
    - Call sendMessage('hello')
    - Verify message wrapper has error set

  test('historical messages load and unwrap correctly')
    - Seed eventStore with stored gift wrap data
    - Call initialize()
    - Verify state contains correctly unwrapped messages

  test('getAdminSharedKey returns 32 bytes from session')
    - Setup session with known admin shared key
    - Call getAdminSharedKey()
    - Verify returns correct 32-byte Uint8List
```

---

## Phase 3: Multimedia Rendering in Dispute Chat
**Status:** `TODO`
**PR scope:** UI changes — display multimedia messages in dispute bubbles
**Depends on:** Phase 2 completed

### What you can test after this phase

> **Second visible milestone:** If the admin sends you an image or file (using the same JSON format as P2P chat), you can **see it rendered inline** in the dispute chat. You can tap images to view full-size and download files.

**Manual testing checklist:**
- [ ] Admin sends an encrypted image message (JSON with `type: "image_encrypted"`) — image renders inline in the dispute chat
- [ ] Admin sends an encrypted file message (JSON with `type: "file_encrypted"`) — file card renders with filename, size, download button
- [ ] Tap on received image — opens full-size view
- [ ] Tap download on received file — file downloads, decrypts, and opens
- [ ] Regular text messages still render normally (no regression)
- [ ] P2P chat multimedia still works (no regression from widget decoupling)
- [ ] Mixed messages (text + images + files) display in correct order
- [ ] Loading spinner shows while image/file is being downloaded and decrypted

**How to test without admin multimedia support:**
You can simulate receiving multimedia by having the admin dev send a chat message with this exact content (as plain text, which gets wrapped in p2pWrap):
```json
{"type":"image_encrypted","blossom_url":"https://blossom.example.com/abc123","nonce":"aabbccdd...","mime_type":"image/jpeg","original_size":50000,"width":800,"height":600,"filename":"test.jpg","encrypted_size":50100}
```
The image won't actually decrypt (fake URL), but you'll see the bubble attempt to render it — confirming the type detection and UI routing work.

### 3.1 Add message type detection to dispute chat

Since dispute messages will now be `NostrEvent` objects (after Phase 2), the existing `MessageTypeUtils` from P2P chat works directly:

**File:** `lib/features/chat/utils/message_type_helpers.dart`

- No changes needed — `MessageTypeUtils.isEncryptedImageMessage()`, `isEncryptedFileMessage()`, and `getMessageType()` all operate on `NostrEvent` and are reusable as-is

### 3.2 Create unified message bubble or reuse existing

**Two approaches:**

**Approach A (Recommended): Reuse `MessageBubble` directly**
- The P2P `MessageBubble` (`lib/features/chat/widgets/message_bubble.dart`) already routes between text/image/file rendering
- It takes `NostrEvent message`, `String peerPubkey`, `String orderId`
- For dispute chat: `peerPubkey` = admin pubkey, `orderId` = session's orderId
- It already handles `isOwnMessage` detection by comparing `message.pubkey` with trade key
- The `EncryptedImageMessage` and `EncryptedFileMessage` widgets need the `orderId` to access `chatRoomsProvider(orderId)` for `getCachedImage()` and `getSharedKey()`
- **Problem:** These widgets call `chatRoomsProvider(orderId)` which is the P2P chat notifier, not the dispute chat notifier. This needs decoupling.

**Approach B: Extract shared rendering into reusable widgets**
- Create a shared interface/callback for getting the shared key and cache
- Pass `getSharedKey` and cache functions as parameters to `EncryptedImageMessage`/`EncryptedFileMessage` instead of hardcoding `chatRoomsProvider`

**Recommended:** Approach B — decouple the multimedia widgets from `chatRoomsProvider`:

### 3.3 Decouple multimedia widgets from P2P chat provider

**File:** `lib/features/chat/widgets/encrypted_image_message.dart`

Current dependency:
```dart
final chatNotifier = ref.read(chatRoomsProvider(orderId).notifier);
final cachedImage = chatNotifier.getCachedImage(messageId);
final sharedKey = await chatNotifier.getSharedKey();
```

Refactor to accept callbacks/providers:
```dart
class EncryptedImageMessage extends ConsumerStatefulWidget {
  final NostrEvent message;
  final Future<Uint8List> Function() getSharedKey;
  final Uint8List? Function(String messageId) getCachedImage;
  final void Function(String messageId, Uint8List data, EncryptedImageUploadResult meta) cacheImage;
  // ...
}
```

Same refactor for `EncryptedFileMessage`.

Then both P2P chat and dispute chat pass their own implementations:
- P2P: passes `chatRoomNotifier.getSharedKey`, `chatRoomNotifier.getCachedImage`, etc.
- Dispute: passes `disputeChatNotifier.getAdminSharedKey`, dispute-specific cache methods

### 3.4 Update `DisputeMessageBubble` to support multimedia

**Option A:** Replace `DisputeMessageBubble` with the refactored `MessageBubble` from P2P chat.

**Option B (Recommended):** Create a new `DisputeMessageBubble` that delegates to the same shared rendering components:

```dart
// In dispute_message_bubble.dart
if (MessageTypeUtils.isEncryptedImageMessage(event)) {
  return EncryptedImageMessage(
    message: event,
    getSharedKey: () => disputeNotifier.getAdminSharedKey(),
    getCachedImage: (id) => disputeNotifier.getCachedImage(id),
    cacheImage: (id, data, meta) => disputeNotifier.cacheDecryptedImage(id, data, meta),
  );
}
if (MessageTypeUtils.isEncryptedFileMessage(event)) {
  return EncryptedFileMessage(...);
}
return /* text bubble */;
```

### 3.5 Add image/file cache to `DisputeChatNotifier`

Add the same cache maps that `ChatRoomNotifier` has:

```dart
final Map<String, Uint8List> _imageCache = {};
final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
final Map<String, Uint8List> _fileCache = {};
final Map<String, EncryptedFileUploadResult> _fileMetadata = {};
```

Plus `getCachedImage()`, `cacheDecryptedImage()`, `getCachedFile()`, `cacheDecryptedFile()`, `getImageMetadata()`, `getFileMetadata()`.

**Consider:** Extracting these caches into a shared mixin or utility class to avoid duplication between `ChatRoomNotifier` and `DisputeChatNotifier`.

### 3.6 Update `DisputeMessagesList` to use new bubble

**File:** `lib/features/disputes/widgets/dispute_messages_list.dart`

- Update the message rendering to use the new multimedia-aware bubble
- Pass the `NostrEvent` (or wrapper) instead of plain string

### 3.7 Tests to create

**File:** `test/features/disputes/dispute_multimedia_rendering_test.dart`

```
group('Dispute chat message type detection')
  test('detects encrypted image message from NostrEvent content')
    - Create NostrEvent with content = jsonEncode({"type":"image_encrypted",...})
    - Assert MessageTypeUtils.isEncryptedImageMessage() returns true

  test('detects encrypted file message from NostrEvent content')
    - Create NostrEvent with content = jsonEncode({"type":"file_encrypted",...})
    - Assert MessageTypeUtils.isEncryptedFileMessage() returns true

  test('plain text message is not detected as multimedia')
    - Create NostrEvent with content = "hello"
    - Assert both detection methods return false

group('Decoupled EncryptedImageMessage / EncryptedFileMessage')
  test('calls getSharedKey callback when loading image')
    - Provide mock getSharedKey that returns test key bytes
    - Verify callback was invoked

  test('calls cacheImage callback after successful download')
    - Mock download service
    - Verify cacheImage callback was invoked with correct data
```

**File:** `test/features/chat/widgets/encrypted_image_message_test.dart` (regression)

```
group('P2P EncryptedImageMessage regression after decoupling')
  test('still works with chatRoomsProvider-based callbacks')
    - Verify existing P2P rendering still functions after refactor
```

---

## Phase 4: Multimedia Sending in Dispute Chat
**Status:** `TODO`
**PR scope:** UI changes — add attachment button and upload flow
**Depends on:** Phase 3 completed

### What you can test after this phase

> **Third visible milestone (feature complete):** You can now **send images and files** to the admin from the dispute chat. The full multimedia flow is complete in both directions.

**Manual testing checklist:**
- [ ] Attachment button (paper clip icon) appears in dispute chat input when status is 'in-progress'
- [ ] Attachment button does NOT appear when dispute status is 'initiated' or 'resolved'
- [ ] Tap attachment — file picker opens with correct allowed file types
- [ ] Select an image — confirmation dialog shows filename
- [ ] Confirm — loading spinner appears on the button
- [ ] Image uploads, encrypts, sends — admin receives and can decrypt/view it
- [ ] Select a document (PDF, etc.) — same flow, admin receives the file
- [ ] Cancel the confirmation dialog — nothing happens, no upload
- [ ] Upload error (no network) — snackbar shows error message
- [ ] Send a mix of text, images, and files — all render correctly in the conversation
- [ ] Admin sends multimedia back — you can see/download it (Phase 3 already covers this)

### 4.1 Add attachment capability to `DisputeMessageInput`

**File:** `lib/features/disputes/widgets/dispute_message_input.dart`

Add the same attachment flow that `MessageInput` has:
- Add `+` / attach button (paper clip icon) to the left of the text field
- Add `_isUploadingFile` state with loading spinner
- Add `_selectAndUploadFile()` method
- Add confirmation dialog before upload
- Add file picker with same allowed extensions

**Key dependency:** The method needs access to the admin shared key to encrypt files. It will call `disputeChatNotifier.getAdminSharedKey()`.

### 4.2 Implement file upload flow in dispute context

The upload flow is identical to P2P:
1. Select file via `FilePicker`
2. Detect if image or document via MIME detection
3. Get admin shared key from `DisputeChatNotifier`
4. Encrypt with `EncryptedImageUploadService` or `EncryptedFileUploadService` (both accept `Uint8List sharedKey`)
5. Upload to Blossom via existing services
6. Send JSON metadata as chat message via `disputeChatNotifier.sendMessage(jsonEncode(result.toJson()))`

### 4.3 Maximize code reuse for upload logic

**Current P2P implementation:** `MessageInput._selectAndUploadFile()` is ~70 lines of upload logic embedded in the widget.

**Refactor opportunity:** Extract the upload logic into a shared utility/service:

```dart
// lib/shared/utils/chat_file_upload_helper.dart
class ChatFileUploadHelper {
  static Future<void> selectAndUploadFile({
    required BuildContext context,
    required Future<Uint8List> Function() getSharedKey,
    required Future<void> Function(String jsonMessage) sendMessage,
    required VoidCallback onUploadStart,
    required VoidCallback onUploadEnd,
  }) async { ... }
}
```

Both `MessageInput` and `DisputeMessageInput` call this helper, passing their respective `getSharedKey` and `sendMessage` implementations.

### 4.4 Tests to create

**File:** `test/features/disputes/dispute_file_upload_test.dart`

```
group('Dispute chat file upload')
  test('encrypts image with admin shared key and uploads to Blossom')
    - Use real crypto keys (KeyDerivator with test mnemonic)
    - Compute admin shared key
    - Encrypt a test image with EncryptedImageUploadService (mock Blossom upload)
    - Decrypt with same shared key
    - Assert decrypted data matches original

  test('encrypts file with admin shared key and uploads to Blossom')
    - Same as above but with EncryptedFileUploadService

  test('upload result JSON round-trips correctly')
    - Create EncryptedImageUploadResult, serialize to JSON, deserialize back
    - Assert all fields match

  test('file encrypted with P2P shared key cannot be decrypted with admin shared key')
    - Encrypt with P2P shared key
    - Try to decrypt with admin shared key
    - Assert fails (session isolation)
```

**Note:** The existing `test/features/chat/file_messaging_test.dart` already tests encryption round-trips and session isolation for P2P. The dispute tests follow the same pattern but verify the admin shared key path.

---

## Phase 5: Cleanup and Code Deduplication
**Status:** `TODO`
**PR scope:** Refactor — no functional changes
**Depends on:** Phase 4 completed

### What you can test after this phase

> **No visible change from the user's perspective.** Everything should work exactly as after Phase 4. This is pure code quality improvement.

**Manual testing checklist (full regression):**
- [ ] Complete dispute flow: create order → take order → open dispute → admin takes dispute → exchange text messages → exchange images → exchange files → resolve dispute
- [ ] Complete P2P chat flow: exchange text, images, and files
- [ ] Historical messages load for both dispute and P2P chat
- [ ] `flutter analyze` passes with zero issues
- [ ] `flutter test` passes — all tests green

### 5.1 Extract shared key bytes conversion to utility

Both `ChatRoomNotifier.getSharedKey()` and `DisputeChatNotifier.getAdminSharedKey()` do the same hex-to-bytes conversion. Extract to:

```dart
// In NostrUtils or a new shared utility
static Uint8List sharedKeyToBytes(NostrKeyPairs sharedKey) {
  final hexKey = sharedKey.private;
  final bytes = Uint8List(32);
  for (int i = 0; i < 32; i++) {
    bytes[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
  }
  return bytes;
}
```

### 5.2 Extract media cache mixin

Both `ChatRoomNotifier` and `DisputeChatNotifier` will have identical image/file cache logic. Extract into a mixin:

```dart
mixin MediaCacheMixin {
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, EncryptedFileUploadResult> _fileMetadata = {};

  Uint8List? getCachedImage(String messageId) => _imageCache[messageId];
  void cacheDecryptedImage(String messageId, Uint8List data, EncryptedImageUploadResult meta) { ... }
  // ... etc
}
```

### 5.3 Remove dead code

- Remove the "dm" skip logic from `MostroService._onData()` (no longer needed after Phase 1)
- Remove any unused imports or methods related to the old `mostroWrap`/`mostroUnWrap` dispute chat flow
- Clean up `DisputeChat` model if it's no longer used (or keep it if still needed for other purposes)

### 5.4 Verify `mostroWrap`/`mostroUnWrap` still needed

These methods are also used for regular Mostro protocol messages (user <-> Mostro daemon), not just dispute chat. Verify usage:
- `mostroWrap`: Check if used in `MostroMessage.wrap()` or other protocol flows
- `mostroUnWrap`: Check if used in `NostrUtils.decryptNIP59Event()` or similar
- **Do NOT delete** if still used for non-dispute protocol messages

### 5.5 Tests to create

**File:** `test/shared/utils/nostr_utils_shared_key_test.dart`

```
group('NostrUtils.sharedKeyToBytes')
  test('converts 64-char hex to 32-byte Uint8List')
  test('throws on invalid hex length')
  test('throws on non-hex characters')
```

**File:** `test/shared/mixins/media_cache_mixin_test.dart`

```
group('MediaCacheMixin')
  test('caches and retrieves image data by messageId')
  test('caches and retrieves file data by messageId')
  test('returns null for uncached messageId')
  test('overwrites cache on duplicate messageId')
```

**Final regression:** Run the full test suite and verify all tests pass.

---

## Testing Timeline Summary

| Phase | When you see results | What you can test |
|-------|---------------------|-------------------|
| **Phase 1** | **Immediately** | Send/receive **text messages** to admin with shared key. First end-to-end verification with admin dev. |
| **Phase 2** | No visible change | Regression only — everything works the same, internal model is unified. |
| **Phase 3** | **After admin sends multimedia** | **See images and files** sent by admin rendered inline. Download and open files. |
| **Phase 4** | **Feature complete** | **Send images and files** to admin. Full bidirectional multimedia. |
| **Phase 5** | No visible change | Full regression — clean code, all tests green. |

## Test Files Summary

| Test File | Phase | What it covers |
|-----------|-------|---------------|
| `test/features/disputes/dispute_shared_key_test.dart` | 1 | ECDH computation, session isolation, admin key independence |
| `test/data/models/nostr_event_wrap_test.dart` | 1 | p2pWrap/p2pUnwrap round-trip, wrong key rejection, event structure |
| `test/features/disputes/dispute_chat_notifier_test.dart` | 2 | NostrEvent state management, pending/error, history, getAdminSharedKey |
| `test/features/disputes/dispute_multimedia_rendering_test.dart` | 3 | Message type detection, decoupled widget callbacks |
| `test/features/chat/widgets/encrypted_image_message_test.dart` | 3 | P2P regression after widget decoupling |
| `test/features/disputes/dispute_file_upload_test.dart` | 4 | Encrypt/upload with admin shared key, session isolation |
| `test/shared/utils/nostr_utils_shared_key_test.dart` | 5 | sharedKeyToBytes utility |
| `test/shared/mixins/media_cache_mixin_test.dart` | 5 | Cache operations |

**Testing patterns to follow:**
- Use `KeyDerivator` with a test mnemonic for real crypto keys (same as `mostro_service_test.dart`)
- Use `ProviderContainer` with overrides for notifier tests
- Use `provideDummy<T>(...)` for non-nullable mocked types
- Import centralized mocks from `test/mocks.dart`
- Run `dart run build_runner build -d` to regenerate mocks after adding new `@GenerateMocks` entries

---

## File Impact Summary

### Files to Modify

| File | Phase | Change |
|------|-------|--------|
| `lib/data/models/session.dart` | 1 | Add `adminSharedKey` field + setter |
| `lib/features/order/models/order_state.dart` | 1 | Compute admin shared key on `adminTookDispute` |
| `lib/features/disputes/notifiers/dispute_chat_notifier.dart` | 1,2,3 | Shared key wrap/unwrap, NostrEvent model, media cache |
| `lib/services/mostro_service.dart` | 1 | Remove "dm" skip logic |
| `lib/features/disputes/widgets/dispute_message_bubble.dart` | 3 | Multimedia-aware rendering |
| `lib/features/disputes/widgets/dispute_messages_list.dart` | 3 | Pass NostrEvent to bubbles |
| `lib/features/disputes/widgets/dispute_message_input.dart` | 4 | Add attachment button + upload flow |
| `lib/features/chat/widgets/encrypted_image_message.dart` | 3 | Decouple from `chatRoomsProvider` |
| `lib/features/chat/widgets/encrypted_file_message.dart` | 3 | Decouple from `chatRoomsProvider` |
| `lib/features/chat/widgets/message_bubble.dart` | 3 | Update to use decoupled widgets |
| `lib/features/chat/widgets/message_input.dart` | 4,5 | Use shared upload helper |

### Files to Create

| File | Phase | Purpose |
|------|-------|---------|
| `lib/shared/utils/chat_file_upload_helper.dart` | 4 | Shared file upload logic |
| `lib/shared/mixins/media_cache_mixin.dart` | 5 | Shared media cache logic |
| `test/features/disputes/dispute_shared_key_test.dart` | 1 | Shared key computation tests |
| `test/data/models/nostr_event_wrap_test.dart` | 1 | Wrap/unwrap round-trip tests |
| `test/features/disputes/dispute_chat_notifier_test.dart` | 2 | Notifier state management tests |
| `test/features/disputes/dispute_multimedia_rendering_test.dart` | 3 | Multimedia type detection tests |
| `test/features/disputes/dispute_file_upload_test.dart` | 4 | File upload encryption tests |
| `test/shared/utils/nostr_utils_shared_key_test.dart` | 5 | Utility tests |
| `test/shared/mixins/media_cache_mixin_test.dart` | 5 | Cache mixin tests |

### Files Reused Without Changes

| File | Used In |
|------|---------|
| `lib/services/encryption_service.dart` | All phases — ChaCha20-Poly1305 |
| `lib/services/encrypted_image_upload_service.dart` | Phase 4 — image encrypt/upload/download |
| `lib/services/encrypted_file_upload_service.dart` | Phase 4 — file encrypt/upload/download |
| `lib/services/blossom_upload_helper.dart` | Phase 4 — Blossom upload |
| `lib/services/blossom_download_service.dart` | Phase 3 — Blossom download |
| `lib/services/media_validation_service.dart` | Phase 4 — image validation |
| `lib/services/file_validation_service.dart` | Phase 4 — file validation |
| `lib/features/chat/utils/message_type_helpers.dart` | Phase 3 — type detection |
| `lib/shared/utils/nostr_utils.dart` | Phase 1 — `computeSharedKey()` |
| `lib/data/models/nostr_event.dart` | Phase 1 — `p2pWrap()`/`p2pUnwrap()` |

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Admin dev not ready for shared key | Phase 1 requires coordination — agree on protocol spec first |
| Breaking existing dispute flow | Phase 1 is the only risky phase — test thoroughly with checklist above |
| `mostroWrap`/`mostroUnWrap` removal breaks protocol messages | Verify usage before removing — they're used for Mostro daemon communication too |
| Large PR size | Each phase is a separate PR with clear scope |
| Multimedia widget coupling | Phase 3 decoupling is the key architectural decision — do it right |
| Regression in P2P chat | Phase 3 widget refactor must include P2P regression tests |

---

*Last updated: 2026-02-16*
