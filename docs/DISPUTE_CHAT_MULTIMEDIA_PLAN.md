# Dispute Chat: Shared Key + Multimedia Implementation Plan

> Technical roadmap for migrating the user-admin dispute chat from direct gift wrap to shared key encryption, and adding multimedia support via Blossom servers.

## Context

Currently the app has two completely different chat mechanisms:

| | P2P Chat (User-User) | Dispute Chat (User-Admin) |
|-|----------------------|--------------------------|
| **Wrap** | `p2pWrap()` — 1 layer | `p2pWrap()` — 1 layer *(Phase 1)* |
| **Key** | Shared key (ECDH) | Admin shared key (ECDH) *(Phase 1)* |
| **Routing (`p` tag)** | Shared key pubkey | Admin shared key pubkey *(Phase 1)* |
| **Subscription** | `SubscriptionManager.chat` | Independent subscription |
| **Message model** | `NostrEvent` | `DisputeChatMessage(NostrEvent)` *(Phase 2)* |
| **Storage** | Gift wrap (encrypted) | Gift wrap (encrypted) *(Phase 2)* |
| **Content format** | Plain text / JSON | Plain text *(Phase 1)* |
| **Multimedia** | Images + files via Blossom | Not supported yet |
| **Message bubble** | `MessageBubble` (routes text/image/file) | `DisputeMessageBubble` (text only) |
| **Input widget** | `MessageInput` (text + attachment) | `DisputeMessageInput` (text only) |

**Goal:** Unify both chats to use the same shared key mechanism and enable multimedia in dispute chat, maximizing code reuse and eliminating redundancy.

---

## Phase Reordering Justification (2026-03-03)

The original plan had this order:
- Phase 3: Multimedia **Rendering** (receive & display images/files from admin)
- Phase 4: Multimedia **Sending** (upload images/files to admin)

**The order has been reversed.** Here's why:

### 1. User need is sending, not receiving
In a dispute, the user needs to send evidence (screenshots, receipts, documents) to the admin. The admin has their own tools to view what they receive. The user does **not** urgently need to see multimedia from the admin — text instructions are sufficient for now.

### 2. Sending does not require desacoplamiento
The original Phase 3 (rendering) required a significant refactor: decoupling `EncryptedImageMessage` and `EncryptedFileMessage` widgets from `chatRoomsProvider`, adding media cache infrastructure to `DisputeChatNotifier`, and ensuring P2P regression. This is a lot of work with regression risk, and it's not needed just to upload files.

The upload services (`EncryptedImageUploadService`, `EncryptedFileUploadService`, `BlossomUploadHelper`) are **already fully decoupled** — they accept `Uint8List sharedKey` as a parameter and have zero coupling to any chat provider. They can be used directly from the dispute input widget.

### 3. Placeholder is sufficient for sent messages
After sending multimedia, the user sees the message in their own chat. A simple placeholder (icon + filename + size) is acceptable UX — the user already knows what they sent. Full inline rendering (downloading, decrypting, and displaying the image they just uploaded) is unnecessary overhead for this phase.

### 4. Clean phase boundary
- **New Phase 3**: Sending + placeholder (self-contained, no P2P widget changes)
- **New Phase 4**: Full rendering for received multimedia (desacoplamiento, cache, P2P regression — can be done later when needed)

This means Phase 3 can ship as a single PR that only touches dispute chat files, with zero risk to existing P2P chat.

---

## Phase 1: Shared Key for Dispute Chat (Protocol Change)
**Status:** `DONE`
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

```text
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

```text
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
**Status:** `DONE`
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

```text
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

## Phase 3: Multimedia Sending in Dispute Chat
**Status:** `TODO`
**Branch:** `phase-3-dispute-multimedia-send`
**PR scope:** UI changes — add attachment button, upload flow, and simple placeholder for sent multimedia
**Depends on:** Phase 2 completed

### What you can test after this phase

> **Second visible milestone:** You can **send images and files** to the admin from the dispute chat. The admin receives them encrypted and can decrypt/view them on their side. Sent multimedia shows as a simple placeholder (icon + filename + size) in your own chat.

**Manual testing checklist:**
- [ ] Attachment button (paper clip icon) appears in dispute chat input
- [ ] Tap attachment — file picker opens with correct allowed file types
- [ ] Select an image — confirmation dialog shows filename
- [ ] Confirm — loading spinner appears on the attach button
- [ ] Image uploads, encrypts, sends — admin receives and can decrypt/view it
- [ ] Select a document (PDF, etc.) — same flow, admin receives the file
- [ ] Cancel the confirmation dialog — nothing happens, no upload
- [ ] Upload error (no network) — snackbar shows error message
- [ ] After sending image — placeholder shows in chat (camera icon + filename + size), NOT raw JSON
- [ ] After sending file — placeholder shows in chat (file icon + filename + size), NOT raw JSON
- [ ] Regular text messages still render normally (no regression)
- [ ] P2P chat still works completely (no changes to P2P files)
- [ ] Historical messages with multimedia placeholders load correctly after app restart

### Why this works without decoupling P2P widgets

The upload services are **already fully decoupled**:

```text
EncryptedImageUploadService.uploadEncryptedImage(imageFile, sharedKey)  // Uint8List param
EncryptedFileUploadService.uploadEncryptedFile(file, sharedKey)         // Uint8List param
BlossomUploadHelper.uploadWithRetry(data, mimeType)                    // No key at all
EncryptionService.encryptChaCha20Poly1305(key, plaintext)              // Pure function
MediaValidationService.validateAndSanitizeImageLight(imageData)        // Pure function
FileValidationService.validateFile(file)                               // Pure function
```

None of these depend on any chat provider. They all accept raw parameters. The dispute input widget can use them directly with `getAdminSharedKey()`.

The only coupling is in the **rendering** widgets (`EncryptedImageMessage`, `EncryptedFileMessage`) which call `chatRoomsProvider(orderId)` — but we don't use those in this phase. We use a simple placeholder instead.

### 3.1 Update `DisputeMessageBubble` to support multimedia placeholders

**File:** `lib/features/disputes/widgets/dispute_message_bubble.dart`

**Current interface:**
```dart
DisputeMessageBubble({
  required String message,       // plain text content
  required bool isFromUser,
  required DateTime timestamp,
  String? adminPubkey,
})
```

**New interface:**
```dart
DisputeMessageBubble({
  required DisputeChatMessage message,  // full wrapper with NostrEvent
  required bool isFromUser,
})
```

**Changes:**
- Accept `DisputeChatMessage` instead of `String message` + `DateTime timestamp`
- Extract `content`, `timestamp` from `message.event`
- Detect message type using `MessageTypeUtils.getMessageType(message.event)`
- Route rendering:
  - `MessageContentType.text` → existing text bubble (no change)
  - `MessageContentType.encryptedImage` → image placeholder widget
  - `MessageContentType.encryptedFile` → file placeholder widget

**Image placeholder:** Parse JSON to extract metadata, then show:
```text
┌─────────────────────────────┐
│  📷  test.jpg               │
│  50.0 KB · Encrypted        │
└─────────────────────────────┘
```

**File placeholder:** Same pattern:
```text
┌─────────────────────────────┐
│  📄  document.pdf           │
│  1.2 MB · Encrypted         │
└─────────────────────────────┘
```

**Design details:**
- Use `Icons.image` for images, `Icons.insert_drive_file` for files
- Show filename (from JSON `filename` field)
- Show human-readable size (from JSON `original_size` field)
- Show "Encrypted" badge (reuse existing `encrypted` localization key)
- Same bubble color scheme as text messages (user vs admin differentiation)
- Long-press to copy is NOT applicable for multimedia placeholders

**Helper method for size formatting:**
```dart
String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
```

### 3.2 Update `DisputeMessagesList` to pass full message to bubble

**File:** `lib/features/disputes/widgets/dispute_messages_list.dart`

**Current (line ~141-149):**
```dart
DisputeMessageBubble(
  message: message.content,
  isFromUser: notifier.isFromUser(message),
  timestamp: message.timestamp,
)
```

**New:**
```dart
DisputeMessageBubble(
  message: message,
  isFromUser: notifier.isFromUser(message),
)
```

Minimal change — just pass the full `DisputeChatMessage` wrapper instead of extracting `.content`.

### 3.3 Add attachment capability to `DisputeMessageInput`

**File:** `lib/features/disputes/widgets/dispute_message_input.dart`

**Current state:** Text-only input with send button (~117 lines).

**Add the following, following the same pattern as `message_input.dart`:**

**New state variables:**
```dart
bool _isUploadingFile = false;
final EncryptedImageUploadService _imageUploadService = EncryptedImageUploadService();
final EncryptedFileUploadService _fileUploadService = EncryptedFileUploadService();
```

**New UI element:** Attach button (paper clip icon) to the left of the text field:
```dart
IconButton(
  icon: _isUploadingFile
    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
    : Icon(Icons.attach_file),
  onPressed: _isUploadingFile ? null : _selectAndUploadFile,
)
```

**Upload flow (`_selectAndUploadFile()`):**

This follows the exact same pipeline as `MessageInput._selectAndUploadFile()`:

1. **File selection:** `FilePicker.platform.pickFiles()` with extensions from `FileValidationService.supportedExtensions`
2. **Confirmation dialog:** Show filename, ask "Send this file?" with Cancel/Send buttons
3. **MIME detection:** Use `lookupMimeType()` on bytes + extension fallback (same `_isImageFile` / `_getMimeType` helpers from P2P)
4. **Get shared key:** `await ref.read(disputeChatNotifierProvider(disputeId).notifier).getAdminSharedKey()`
5. **Encrypt + upload:**
   - If image: `_imageUploadService.uploadEncryptedImage(imageFile: file, sharedKey: key, filename: name)`
   - If file: `_fileUploadService.uploadEncryptedFile(file: file, sharedKey: key)`
6. **Send JSON metadata:** `await ref.read(disputeChatNotifierProvider(disputeId).notifier).sendMessage(jsonEncode(result.toJson()))`
7. **Error handling:** try/catch, show snackbar with `errorUploadingFile` localized message

**Why duplicate instead of extract to helper?** The upload logic in `MessageInput` is ~70 lines embedded in the widget. Extracting to a shared helper is a Phase 5 cleanup task. For now, adapting the same pattern in `DisputeMessageInput` is simpler and avoids touching `MessageInput` (zero P2P regression risk). The two implementations are nearly identical except for how they get the shared key and send the message:
- P2P: `chatRoomsProvider(orderId).notifier.getSharedKey()` / `.sendMessage()`
- Dispute: `disputeChatNotifierProvider(disputeId).notifier.getAdminSharedKey()` / `.sendMessage()`

### 3.4 MIME detection helpers

Copy the two helper methods from `MessageInput` into `DisputeMessageInput`:

```dart
bool _isImageFile(Uint8List bytes, String filename) {
  final mimeType = _getMimeType(bytes, filename);
  return mimeType != null && mimeType.startsWith('image/');
}

String? _getMimeType(Uint8List bytes, String filename) {
  final mimeType = lookupMimeType(filename, headerBytes: bytes);
  if (mimeType != null) return mimeType;
  final ext = filename.split('.').last.toLowerCase();
  // extension fallback map...
}
```

These are pure functions with no provider coupling — safe to duplicate. Phase 5 can extract them to a shared utility.

### 3.5 Confirmation dialog

Same pattern as `MessageInput._showFileConfirmationDialog()`:

```dart
Future<bool> _showFileConfirmationDialog(String filename) async {
  return await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(S.of(context)!.sendThisFile),
      content: Text(filename),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(S.of(context)!.cancel)),
        TextButton(onPressed: () => Navigator.pop(context, true), child: Text(S.of(context)!.send)),
      ],
    ),
  ) ?? false;
}
```

All localization keys (`sendThisFile`, `cancel`, `send`, `errorUploadingFile`) already exist in all three languages.

### 3.6 No changes to `DisputeChatNotifier`

The notifier's `sendMessage(String text)` method already works for any string content — including JSON. When the user sends a file:
1. Upload service returns `EncryptedImageUploadResult` or `EncryptedFileUploadResult`
2. Widget calls `sendMessage(jsonEncode(result.toJson()))`
3. Notifier wraps it in `p2pWrap()`, publishes, stores gift wrap — same as text

No new methods needed on the notifier for this phase.

### 3.7 Localization

**Existing keys (no new keys needed):**
- `sendThisFile` — "Send this file?" (confirmation dialog)
- `send` — "Send" (button)
- `cancel` — "Cancel" (button)
- `errorUploadingFile` — "Error uploading file: {error}" (snackbar)
- `encrypted` — "Encrypted" (badge on placeholder)
- `failedSendMessage` — "Failed to send message: {error}" (send error)

**New keys needed for placeholders:**
- `imageSent` — "Image" (placeholder label for sent images)
- `fileSent` — "File" (placeholder label for sent files)

Add to all three ARB files (`intl_en.arb`, `intl_es.arb`, `intl_it.arb`).

### 3.8 Tests to create

**File:** `test/features/disputes/dispute_multimedia_send_test.dart`

```text
group('Dispute chat multimedia sending')
  test('encrypts image with admin shared key and uploads to Blossom')
    - Use real crypto keys (KeyDerivator with test mnemonic)
    - Compute admin shared key (ECDH)
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

**File:** `test/features/disputes/dispute_message_bubble_test.dart`

```text
group('DisputeMessageBubble multimedia placeholders')
  test('renders text message as text bubble')
    - Create DisputeChatMessage with plain text content
    - Assert text bubble rendered, no placeholder

  test('renders image_encrypted as image placeholder')
    - Create DisputeChatMessage with content = jsonEncode({"type":"image_encrypted","filename":"test.jpg","original_size":50000,...})
    - Assert image icon and filename displayed
    - Assert "Encrypted" badge shown
    - Assert raw JSON NOT visible

  test('renders file_encrypted as file placeholder')
    - Create DisputeChatMessage with content = jsonEncode({"type":"file_encrypted","filename":"doc.pdf","original_size":1200000,...})
    - Assert file icon and filename displayed

  test('renders malformed JSON as plain text')
    - Create DisputeChatMessage with content = "{invalid json"
    - Assert treated as text message (graceful fallback)
```

**Note:** The existing `test/features/chat/file_messaging_test.dart` already tests encryption round-trips for P2P. The dispute tests follow the same pattern but verify the admin shared key path.

---

## Phase 4: Multimedia Rendering in Dispute Chat (Receive & Display)
**Status:** `TODO` (future)
**PR scope:** UI changes — display multimedia messages from admin with inline rendering
**Depends on:** Phase 3 completed

### What you can test after this phase

> **Third visible milestone:** If the admin sends you an image or file, you can **see it rendered inline** in the dispute chat. You can tap images to view full-size and download files. Combined with Phase 3, this completes bidirectional multimedia.

**Manual testing checklist:**
- [ ] Admin sends an encrypted image message — image renders inline in the dispute chat
- [ ] Admin sends an encrypted file message — file card renders with filename, size, download button
- [ ] Tap on received image — opens full-size view
- [ ] Tap download on received file — file downloads, decrypts, and opens
- [ ] Your own sent images also render inline (upgrade from placeholder)
- [ ] Regular text messages still render normally (no regression)
- [ ] P2P chat multimedia still works (no regression from widget decoupling)
- [ ] Mixed messages (text + images + files) display in correct order
- [ ] Loading spinner shows while image/file is being downloaded and decrypted

### 4.1 Decouple multimedia widgets from P2P chat provider

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

### 4.2 Add image/file cache to `DisputeChatNotifier`

Add the same cache maps that `ChatRoomNotifier` has:

```dart
final Map<String, Uint8List> _imageCache = {};
final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
final Map<String, Uint8List> _fileCache = {};
final Map<String, EncryptedFileUploadResult> _fileMetadata = {};
```

Plus `getCachedImage()`, `cacheDecryptedImage()`, `getCachedFile()`, `cacheDecryptedFile()`, `getImageMetadata()`, `getFileMetadata()`.

**Consider:** Extracting these caches into a shared mixin or utility class to avoid duplication between `ChatRoomNotifier` and `DisputeChatNotifier`.

### 4.3 Update `DisputeMessageBubble` to use full rendering

Replace the placeholders from Phase 3 with the decoupled `EncryptedImageMessage` / `EncryptedFileMessage` widgets:

```dart
if (MessageTypeUtils.isEncryptedImageMessage(event)) {
  return EncryptedImageMessage(
    message: event,
    getSharedKey: () => disputeNotifier.getAdminSharedKey(),
    getCachedImage: (id) => disputeNotifier.getCachedImage(id),
    cacheImage: (id, data, meta) => disputeNotifier.cacheDecryptedImage(id, data, meta),
  );
}
```

### 4.4 Add message content processing to `DisputeChatNotifier`

Add `_processMessageContent()` to auto-download images when messages arrive (same pattern as `ChatRoomNotifier`):

```dart
Future<void> _processMessageContent(NostrEvent message) async {
  try {
    final content = message.content;
    if (content == null || !content.startsWith('{')) return;
    final jsonData = jsonDecode(content) as Map<String, dynamic>;
    if (MessageTypeUtils.isEncryptedImageMessage(message)) {
      await _processEncryptedImageMessage(message, jsonData);
    } else if (MessageTypeUtils.isEncryptedFileMessage(message)) {
      await _processEncryptedFileMessage(message, jsonData);
    }
  } catch (e) {
    // Don't rethrow — message still displays as text/placeholder
  }
}
```

### 4.5 Tests to create

**File:** `test/features/disputes/dispute_multimedia_rendering_test.dart`

```text
group('Dispute chat message type detection')
  test('detects encrypted image message from NostrEvent content')
  test('detects encrypted file message from NostrEvent content')
  test('plain text message is not detected as multimedia')

group('Decoupled EncryptedImageMessage / EncryptedFileMessage')
  test('calls getSharedKey callback when loading image')
  test('calls cacheImage callback after successful download')
```

**File:** `test/features/chat/widgets/encrypted_image_message_test.dart` (regression)

```text
group('P2P EncryptedImageMessage regression after decoupling')
  test('still works with chatRoomsProvider-based callbacks')
```

---

## Phase 5: Cleanup and Code Deduplication
**Status:** `TODO` (future)
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

### 5.3 Extract shared upload helper

Both `MessageInput` and `DisputeMessageInput` will have similar upload logic. Extract to:

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

Both widgets call this helper, passing their respective `getSharedKey` and `sendMessage` implementations.

### 5.4 Extract MIME detection helpers

`_isImageFile()` and `_getMimeType()` will be duplicated between `MessageInput` and `DisputeMessageInput`. Extract to a shared utility.

### 5.5 Add missing `mounted` checks to P2P `MessageInput`

**File:** `lib/features/chat/widgets/message_input.dart`

The P2P `MessageInput._selectAndUploadFile()` is missing `mounted` checks after async operations (`FilePicker.platform.pickFiles()` and `_showFileConfirmationDialog()`). The dispute version (`DisputeMessageInput`) already has them — this was caught during Phase 3 code review. Add the same two `if (!mounted) return;` checks to the P2P widget for consistency.

### 5.6 Remove dead code

- Remove the "dm" skip logic from `MostroService._onData()` (no longer needed after Phase 1)
- Remove any unused imports or methods related to the old `mostroWrap`/`mostroUnWrap` dispute chat flow
- Clean up `DisputeChat` model if it's no longer used (or keep it if still needed for other purposes)

### 5.7 Verify `mostroWrap`/`mostroUnWrap` still needed

These methods are also used for regular Mostro protocol messages (user <-> Mostro daemon), not just dispute chat. Verify usage:
- `mostroWrap`: Check if used in `MostroMessage.wrap()` or other protocol flows
- `mostroUnWrap`: Check if used in `NostrUtils.decryptNIP59Event()` or similar
- **Do NOT delete** if still used for non-dispute protocol messages

### 5.8 Tests to create

**File:** `test/shared/utils/nostr_utils_shared_key_test.dart`

```text
group('NostrUtils.sharedKeyToBytes')
  test('converts 64-char hex to 32-byte Uint8List')
  test('throws on invalid hex length')
  test('throws on non-hex characters')
```

**File:** `test/shared/mixins/media_cache_mixin_test.dart`

```text
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
| **Phase 3** | **Feature milestone** | **Send images and files** to admin. Sent multimedia shows as placeholder in your chat. |
| **Phase 4** | **Full multimedia** | **See images and files** from admin rendered inline. Full bidirectional multimedia. |
| **Phase 5** | No visible change | Full regression — clean code, all tests green. |

## Test Files Summary

| Test File | Phase | What it covers |
|-----------|-------|---------------|
| `test/features/disputes/dispute_shared_key_test.dart` | 1 | ECDH computation, session isolation, admin key independence |
| `test/data/models/nostr_event_wrap_test.dart` | 1 | p2pWrap/p2pUnwrap round-trip, wrong key rejection, event structure |
| `test/features/disputes/dispute_chat_notifier_test.dart` | 2 | NostrEvent state management, pending/error, history, getAdminSharedKey |
| `test/features/disputes/dispute_multimedia_send_test.dart` | 3 | Encrypt/upload with admin shared key, session isolation, JSON round-trip |
| `test/features/disputes/dispute_message_bubble_test.dart` | 3 | Placeholder rendering, type detection, graceful fallback |
| `test/features/disputes/dispute_multimedia_rendering_test.dart` | 4 | Decoupled widget callbacks, message type detection |
| `test/features/chat/widgets/encrypted_image_message_test.dart` | 4 | P2P regression after widget decoupling |
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

### Phase 3 Files (Current Phase)

**Files to modify:**

| File | Change |
|------|--------|
| `lib/features/disputes/widgets/dispute_message_bubble.dart` | Accept `DisputeChatMessage`, add multimedia placeholders |
| `lib/features/disputes/widgets/dispute_messages_list.dart` | Pass full `DisputeChatMessage` to bubble |
| `lib/features/disputes/widgets/dispute_message_input.dart` | Add attach button, upload flow, confirmation dialog |
| `lib/l10n/intl_en.arb` | Add `imageSent`, `fileSent` keys |
| `lib/l10n/intl_es.arb` | Add `imageSent`, `fileSent` keys |
| `lib/l10n/intl_it.arb` | Add `imageSent`, `fileSent` keys |

**Files NOT modified (zero P2P regression risk):**

| File | Why not touched |
|------|----------------|
| `lib/features/chat/widgets/encrypted_image_message.dart` | No decoupling in this phase |
| `lib/features/chat/widgets/encrypted_file_message.dart` | No decoupling in this phase |
| `lib/features/chat/widgets/message_bubble.dart` | No changes needed |
| `lib/features/chat/widgets/message_input.dart` | No extraction in this phase |
| `lib/features/disputes/notifiers/dispute_chat_notifier.dart` | `sendMessage()` already works for JSON |

**Test files to create:**

| File | Purpose |
|------|---------|
| `test/features/disputes/dispute_multimedia_send_test.dart` | Encryption round-trip with admin key, JSON serialization |
| `test/features/disputes/dispute_message_bubble_test.dart` | Placeholder rendering, type detection |

**Services reused without changes:**

| File | Used for |
|------|----------|
| `lib/services/encrypted_image_upload_service.dart` | Image encrypt + upload |
| `lib/services/encrypted_file_upload_service.dart` | File encrypt + upload |
| `lib/services/blossom_upload_helper.dart` | Blossom server upload |
| `lib/services/encryption_service.dart` | ChaCha20-Poly1305 |
| `lib/services/media_validation_service.dart` | Image validation |
| `lib/services/file_validation_service.dart` | File validation |
| `lib/features/chat/utils/message_type_helpers.dart` | Type detection |

### Phase 4+ Files (Future)

| File | Phase | Change |
|------|-------|--------|
| `lib/features/chat/widgets/encrypted_image_message.dart` | 4 | Decouple from `chatRoomsProvider` |
| `lib/features/chat/widgets/encrypted_file_message.dart` | 4 | Decouple from `chatRoomsProvider` |
| `lib/features/chat/widgets/message_bubble.dart` | 4 | Update to use decoupled widgets |
| `lib/features/disputes/notifiers/dispute_chat_notifier.dart` | 4 | Add media cache + message processing |
| `lib/features/disputes/widgets/dispute_message_bubble.dart` | 4 | Replace placeholders with inline rendering |
| `lib/features/chat/widgets/message_input.dart` | 5 | Use shared upload helper |
| `lib/shared/utils/chat_file_upload_helper.dart` | 5 | New — shared upload logic |
| `lib/shared/mixins/media_cache_mixin.dart` | 5 | New — shared cache logic |

---

## Risk Assessment

| Risk | Mitigation |
|------|-----------|
| Admin dev not ready for shared key | Phase 1 requires coordination — agree on protocol spec first |
| Breaking existing dispute flow | Phase 1 is the only risky phase — test thoroughly with checklist above |
| `mostroWrap`/`mostroUnWrap` removal breaks protocol messages | Verify usage before removing — they're used for Mostro daemon communication too |
| Large PR size | Each phase is a separate PR with clear scope |
| Phase 3 upload regression | Upload services are pure/decoupled — no P2P files touched |
| Multimedia widget coupling (Phase 4) | Deferred to its own phase — no risk in Phase 3 |
| Code duplication (MIME helpers, upload logic) | Acceptable in Phase 3, cleaned up in Phase 5 |
| Regression in P2P chat | Phase 3 does NOT touch any P2P files — zero risk |

---

*Last updated: 2026-03-03*
