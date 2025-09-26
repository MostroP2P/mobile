# Session and Key Management System

This document provides a comprehensive explanation of how the Mostro mobile application handles cryptographic keys, session management, and data storage. It covers the complete lifecycle from key generation to order creation and message handling.

## Table of Contents
- [Key Management Architecture](#key-management-architecture)
- [Identity Key System](#identity-key-system)
- [Trade Keys and Index Management](#trade-keys-and-index-management)
- [Session Management](#session-management)
- [Order Creation Flow](#order-creation-flow)
- [Message Wrapping and NIP-59 Implementation](#message-wrapping-and-nip-59-implementation)
- [Storage Architecture](#storage-architecture)
- [Specific Scenarios](#specific-scenarios)
- [Code Flow Examples](#code-flow-examples)
- [Logging and Debugging](#logging-and-debugging)

## Key Management Architecture

The Mostro mobile app implements a hierarchical deterministic (HD) key derivation system following NIP-06 standards. The architecture consists of three main components:

### Core Classes
- **`KeyManager`** (`lib/features/key_manager/key_manager.dart:6`) - Main orchestrator for all key operations
- **`KeyDerivator`** (`lib/features/key_manager/key_derivator.dart:8`) - Handles BIP39/BIP32 key derivation
- **`KeyStorage`** (`lib/features/key_manager/key_storage.dart:5`) - Manages secure storage of keys and indices

### Derivation Path Structure
All keys in the system follow the derivation path: **`m/44'/1237'/38383'/0/N`**

- `m/44'` - BIP44 standard
- `1237'` - Nostr coin type
- `38383'` - Mostro-specific account
- `0` - External chain (hardcoded)
- `N` - Key index (0 for identity, 1+ for trades)

This path is defined in the `Config` class (`lib/core/config.dart`) and used in the `KeyDerivator` constructor (`lib/features/key_manager/key_manager_provider.dart:14`):
```dart
// In Config class
static const String keyDerivationPath = "m/44'/1237'/38383'/0";

// In key_manager_provider.dart
final keyDerivator = KeyDerivator(Config.keyDerivationPath);
```

## Identity Key System

### Identity Key (Index 0)
The identity key is derived at index `0` of the derivation path: **`m/44'/1237'/38383'/0/0`**

#### Purpose and Usage
- **Reputation System**: Links orders to maintain user reputation across trades
- **Gift Wrap Seal**: Signs the NIP-59 seal layer for message authentication
- **Master Identity**: Persistent identity across all user trading activities

#### Key Generation
Identity key generation occurs in `KeyManager._getMasterKey()` (`lib/features/key_manager/key_manager.dart:54-61`):

```dart
Future<NostrKeyPairs> _getMasterKey() async {
  final masterKeyHex = await _storage.readMasterKey();
  if (masterKeyHex == null) {
    throw MasterKeyNotFoundException('No master key found in secure storage');
  }
  final privKey = _derivator.derivePrivateKey(masterKeyHex, 0); // Index 0 = Identity
  return NostrKeyPairs(private: privKey);
}
```

#### Storage Location
Identity key is stored as part of the master key derivation and accessed through:
- **Secure Storage**: Extended private key in `FlutterSecureStorage`
- **Session Context**: Available in `Session.masterKey` field (`lib/data/models/session.dart:10`)

### Full Privacy Mode
When full privacy mode is enabled (`Settings.fullPrivacyMode`), the identity key is **not** sent to mostrod:
- No reputation tracking possible
- Trade keys used for both seal and rumor signatures
- Enhanced privacy at cost of reputation building

## Trade Keys and Index Management

### Trade Key Generation
Trade keys are derived sequentially starting from index `1`. Each new trade/order gets a unique key.

#### Key Derivation Process
The `KeyManager.deriveTradeKey()` method (`lib/features/key_manager/key_manager.dart:68-82`) handles trade key generation:

```dart
Future<NostrKeyPairs> deriveTradeKey() async {
  final masterKeyHex = await _storage.readMasterKey();
  if (masterKeyHex == null) {
    throw MasterKeyNotFoundException('No master key found in secure storage');
  }
  final currentIndex = await _storage.readTradeKeyIndex(); // Get current index
  
  final tradePrivateHex = _derivator.derivePrivateKey(masterKeyHex, currentIndex);
  
  // Increment index for next trade
  await setCurrentKeyIndex(currentIndex + 1);
  
  return NostrKeyPairs(private: tradePrivateHex);
}
```

#### Index Management
Trade key indices are managed through:
- **Current Index Tracking**: `KeyStorage.readTradeKeyIndex()` (`lib/features/key_manager/key_storage.dart:47-52`)
- **Index Incrementation**: `KeyManager.setCurrentKeyIndex()` (`lib/features/key_manager/key_manager.dart:117-125`)
- **Storage**: Persisted in `SharedPreferences` with key `'key_index'`

#### Index Storage Implementation
```dart
Future<void> storeTradeKeyIndex(int index) async {
  await sharedPrefs.setInt(
    SharedPreferencesKeys.keyIndex.value,  // 'key_index'
    index,
  );
}

Future<int> readTradeKeyIndex() async {
  return await sharedPrefs.getInt(
        SharedPreferencesKeys.keyIndex.value,
      ) ??
      1;  // Default to index 1 (first trade key)
}
```

## Session Management

### Session Architecture
The `Session` class (`lib/data/models/session.dart`) contains all cryptographic context for a trade:

```dart
class Session {
  final NostrKeyPairs masterKey;    // Identity key (index 0)
  final NostrKeyPairs tradeKey;     // Trade-specific key (index N)
  final int keyIndex;               // Index N used for this trade
  final bool fullPrivacy;           // Privacy mode flag
  final DateTime startTime;         // Session creation time
  String? orderId;                  // Associated order ID (after confirmation)
  Role? role;                       // buyer/seller role
  Peer? peer;                       // Counterparty information
}
```

### Session Creation Flow
New sessions are created in `SessionNotifier.newSession()` (`lib/shared/notifiers/session_notifier.dart:73-100`):

```dart
Future<Session> newSession({String? orderId, int? requestId, Role? role}) async {
  if (state.any((s) => s.orderId == orderId)) {
    return state.firstWhere((s) => s.orderId == orderId);
  }
  
  // Get identity key (index 0)
  final masterKey = ref.read(keyManagerProvider).masterKeyPair!;
  
  // Get current trade key index and derive trade key
  final keyIndex = await ref.read(keyManagerProvider).getCurrentKeyIndex();
  final tradeKey = await ref.read(keyManagerProvider).deriveTradeKey();
  
  final session = Session(
    startTime: DateTime.now(),
    masterKey: masterKey,      // Identity key for reputation/seal
    keyIndex: keyIndex,        // Trade key index (1, 2, 3, ...)
    tradeKey: tradeKey,        // Trade key for this specific trade
    fullPrivacy: _settings.fullPrivacyMode,
    orderId: orderId,
    role: role,
  );
  
  // Store session for later retrieval
  if (orderId != null) {
    _sessions[orderId] = session;
  } else if (requestId != null) {
    _requestIdToSession[requestId] = session;
  }
  
  return session;
}
```

### Session Storage and Persistence
Sessions are persisted using `SessionStorage` (`lib/data/repositories/session_storage.dart`) backed by Sembast NoSQL database:

- **Active Sessions**: Stored in memory (`SessionNotifier._sessions` map)
- **Persistent Storage**: Serialized to Sembast for app restart recovery
- **Cleanup**: Automatic cleanup of expired sessions (72 hours default)

### Session Lifecycle and Cleanup

#### **Orphan Session Prevention**
When users take orders, a 30-second cleanup timer is automatically started to prevent orphan sessions:

```dart
// Automatically started when taking orders
AbstractMostroNotifier.startSessionTimeoutCleanup(orderId, ref);
```

**Purpose**: Prevents sessions from becoming orphaned when Mostro instances are unresponsive or offline.

#### **Session Deletion**
Sessions can be deleted through several mechanisms:

1. **Automatic Cleanup**: 30-second timer when no response from Mostro
2. **Timeout Detection**: Real-time detection via public events (taker scenarios)
3. **Cancellation**: When orders are cancelled (pending/waiting states only)
4. **Expiration**: Periodic cleanup of sessions older than 72 hours
5. **Manual**: User-initiated session cleanup through settings

#### **Session Cleanup Implementation**
```dart
// lib/shared/notifiers/session_notifier.dart:157-161
Future<void> deleteSession(String sessionId) async {
  _sessions.remove(sessionId);
  await _storage.deleteSession(sessionId);
  state = sessions; // Update state to trigger UI updates
}
```

#### **Timer Management**
The orphan session prevention system uses static timer storage for proper resource management:

- **Timer Storage**: `Map<String, Timer> _sessionTimeouts`
- **Automatic Cancellation**: Timers cancelled when Mostro responds
- **Disposal Cleanup**: Timers cleaned up when notifiers are disposed
- **Memory Safety**: Prevents timer-related memory leaks

## Order Creation Flow

### Complete Order Creation Process

#### 1. Order Submission
When a user creates a new order, the flow starts in `AddOrderNotifier.submitOrder()` (`lib/features/order/notfiers/add_order_notifier.dart:71-85`):

```dart
Future<void> submitOrder(Order order) async {
  // Create Mostro message
  final message = MostroMessage<Order>(
    action: Action.newOrder,
    id: null,                    // Will be assigned by mostrod
    requestId: requestId,        // Unique request identifier
    payload: order,
  );
  
  // Create new session with fresh trade key
  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  session = await sessionNotifier.newSession(
    requestId: requestId,
    role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
  );
  
  // Send wrapped message to mostrod
  await mostroService.submitOrder(message);
  state = state.updateWith(message);
}
```

#### 2. Message Wrapping and Transmission
The message is processed in `MostroService.publishOrder()` (`lib/services/mostro_service.dart:206-218`):

```dart
Future<void> publishOrder(MostroMessage order) async {
  final session = await _getSession(order);  // Retrieve session by requestId
  
  // Create NIP-59 gift wrap with session keys
  final event = await order.wrap(
    tradeKey: session.tradeKey,              // Trade key for rumor
    recipientPubKey: _settings.mostroPublicKey,
    masterKey: session.fullPrivacy ? null : session.masterKey,  // Identity key for seal (if not full privacy)
    keyIndex: session.fullPrivacy ? null : session.keyIndex,    // Trade index for protocol
  );
  
  _logger.i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
  await ref.read(nostrServiceProvider).publishEvent(event);
}
```

#### 3. Order Confirmation
When mostrod confirms the order, `AddOrderNotifier._confirmOrder()` is called (`lib/features/order/notfiers/add_order_notifier.dart:60-69`):

```dart
Future<void> _confirmOrder(MostroMessage message) async {
  state = state.updateWith(message);
  session.orderId = message.id;  // Link session to confirmed order ID
  
  // Persist session with order ID
  ref.read(sessionNotifierProvider.notifier).saveSession(session);
  
  // Create order-specific notifier for ongoing trade management
  ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
  
  // Navigate to confirmation screen
  ref.read(navigationProvider.notifier).go('/order_confirmed/${message.id!}');
  ref.invalidateSelf();
}
```

## Message Wrapping and NIP-59 Implementation

### Gift Wrap Structure
The Mostro protocol uses NIP-59 gift wrapping with three layers:

1. **Rumor** (kind 1): Contains the actual Mostro message
2. **Seal** (kind 13): Encrypts the rumor using identity key
3. **Wrapper** (kind 1059): Final layer using ephemeral key

### Wrapping Implementation
The complete wrapping process is implemented in `MostroMessage.wrap()` (`lib/data/models/mostro_message.dart:172-193`):

```dart
Future<NostrEvent> wrap({
  required NostrKeyPairs tradeKey,
  required String recipientPubKey,
  NostrKeyPairs? masterKey,
  int? keyIndex,
}) async {
  tradeIndex = keyIndex;  // Set trade index in message
  
  // Serialize message with signature if masterKey provided (non-full-privacy)
  final content = serialize(keyPair: masterKey != null ? tradeKey : null);
  final keySet = masterKey ?? tradeKey;  // Use masterKey for seal, or tradeKey for full privacy
  
  // Create encrypted rumor (layer 1)
  final encryptedContent = await NostrUtils.createRumor(
    tradeKey,           // Trade key signs the rumor
    keySet.private,     // Key used for encryption
    recipientPubKey, 
    content
  );
  
  // Generate ephemeral key for wrapper
  final wrapperKeyPair = NostrUtils.generateKeyPair();
  
  // Create seal (layer 2)
  String sealedContent = await NostrUtils.createSeal(
    keySet,             // Identity key (or trade key in full privacy) signs the seal
    wrapperKeyPair.private, 
    recipientPubKey, 
    encryptedContent
  );
  
  // Create final wrapper (layer 3)
  return await NostrUtils.createWrap(
    wrapperKeyPair, 
    sealedContent, 
    recipientPubKey
  );
}
```

### Key Usage in Gift Wrap Layers

#### Standard Mode (Reputation Enabled)
- **Rumor Content**: Signed by **trade key** 
- **Seal Event**: Signed by **identity key (index 0)**
- **Wrapper Event**: Signed by **ephemeral key**

#### Full Privacy Mode  
- **Rumor Content**: **No signature**
- **Seal Event**: Signed by **trade key**
- **Wrapper Event**: Signed by **ephemeral key**

### Message Signature Process
In standard mode, the rumor content includes a signature (`MostroMessage.serialize()` at `lib/data/models/mostro_message.dart:164-170`):

```dart
String serialize({NostrKeyPairs? keyPair}) {
  final message = {'order': toJson()};
  final serializedEvent = jsonEncode(message);
  final signature = (keyPair != null) ? '"${sign(keyPair)}"' : null;
  final content = '[$serializedEvent, $signature]';  // [message, signature] or [message, null]
  return content;
}
```

## Storage Architecture

### Secure Storage (FlutterSecureStorage)
Sensitive cryptographic material is stored in secure storage:

| Key | Type | Content | Location |
|-----|------|---------|----------|
| `master_key` | String | Extended private key (BIP32) | `SecureStorageKeys.masterKey` |
| `mnemonic` | String | BIP39 seed phrase | `SecureStorageKeys.mnemonic` |

### SharedPreferences Storage
Non-sensitive configuration data:

| Key | Type | Content | Location |
|-----|------|---------|----------|
| `key_index` | int | Current trade key index | `SharedPreferencesKeys.keyIndex` |
| `full_privacy` | bool | Privacy mode setting | `SharedPreferencesKeys.fullPrivacy` |
| `mostro_settings` | JSON | App settings | `SharedPreferencesKeys.appSettings` |

### Sembast Database
Session and order data:

- **Sessions**: Complete session objects with keys and metadata
- **Messages**: Mostro messages associated with orders
- **Events**: Processed Nostr events for deduplication

### Storage Access Patterns

#### Key Storage Implementation (`lib/features/key_manager/key_storage.dart`)
```dart
class KeyStorage {
  final FlutterSecureStorage secureStorage;
  final SharedPreferencesAsync sharedPrefs;

  // Secure storage for sensitive keys
  Future<void> storeMasterKey(String masterKey) async {
    await secureStorage.write(
      key: SecureStorageKeys.masterKey.value,  // 'master_key'
      value: masterKey,
    );
  }

  Future<String?> readMasterKey() async {
    return secureStorage.read(
      key: SecureStorageKeys.masterKey.value,
    );
  }

  // SharedPreferences for trade key index
  Future<void> storeTradeKeyIndex(int index) async {
    await sharedPrefs.setInt(
      SharedPreferencesKeys.keyIndex.value,  // 'key_index'
      index,
    );
  }

  Future<int> readTradeKeyIndex() async {
    return await sharedPrefs.getInt(
          SharedPreferencesKeys.keyIndex.value,
        ) ??
        1;  // Default to first trade key
  }
}
```

## Child Order Session Management After Release

### The Missing Session Problem

When a range order is successfully completed via the `release` action, mostrod creates a child order using the next available trade key that was provided in the `NextTrade` payload. However, the mobile app has a critical gap in handling these child orders: **no session exists for the child order when the `new-order` message arrives**.

#### Current Implementation Flow (Broken)

```
1. Parent Order Release
   → User completes range order (e.g., orderId: "parent-123", keyIndex: 7)
   → App calls KeyManager.getNextKeyIndex() → returns 8
   → App derives trade key for index 8: "05z8y7x6w5..."
   → NextTrade payload sent: {key: "05z8y7x6w5...", index: 8}

2. Mostrod Processing
   → Creates child order with ID "child-456"
   → Uses trade key index 8 for child order encryption
   → Sends new-order message encrypted to "05z8y7x6w5..."

3. App Receives Child Order Message (FAILS HERE)
   → MostroService._onData() receives encrypted message
   → Looks for session with tradeKey.public == "05z8y7x6w5..."
   → NO SESSION FOUND - message is dropped
   → Child order never appears in "My Trades"
```

#### Root Cause Analysis

The issue occurs in `MostroService._onData()` (`lib/services/mostro_service.dart:44-82`):

```dart
Future<void> _onData(NostrEvent event) async {
  // ... event processing ...

  final sessions = ref.read(sessionNotifierProvider);
  final matchingSession = sessions.firstWhereOrNull(
    (s) => s.tradeKey.public == event.recipient,  // event.recipient = "05z8y7x6w5..."
  );

  if (matchingSession == null) {
    logger.w('No matching session found for recipient: ${event.recipient}');
    return;  // ← CHILD ORDER MESSAGE IS DROPPED HERE
  }

  // Message processing continues only if session exists...
}
```

**The problem**: When the `release` action generates the next trade key (index 8), a session is **not** created for that key. The key exists in the KeyManager but no corresponding session exists to handle incoming messages encrypted to that key.

#### Session Creation Gap

Looking at how sessions are normally created:

1. **User-Initiated Orders**: `AddOrderNotifier.submitOrder()` creates session with `newSession(requestId: requestId)`
2. **Taking Orders**: `OrderNotifier.takeBuyOrder()/takeSellOrder()` creates session with `newSession(orderId: orderId)`
3. **Child Orders**: **NO SESSION CREATION MECHANISM EXISTS**

The `AbstractMostroNotifier` no longer performs the linking; that logic now lives alongside the decryption inside `MostroService._maybeLinkChildOrder()`, keeping the data flow contained within the service that already owns the decrypted message.

#### Missing Session Creation for Child Orders

For child orders to work properly, when the app receives a `new-order` message for a child order, it needs to:

1. **Detect Child Order Context**: Recognize this is a child order from a maker's range order
2. **Create Session**: Create a session using the existing trade key for that index
3. **Link to Parent**: Maintain relationship to parent order for UI display
4. **Enable Order Management**: Allow the child order to appear in "My Trades"

### Expected Child Order Flow (Fixed)

```
1. Parent Order Release
   → User completes range order (orderId: "parent-123", keyIndex: 7)
   → App pre-generates child trade key (index 8)
   → NextTrade payload sent with new trade key

2. Child Order Session Preparation
   → App should create session for upcoming child order
   → Session links trade key index 8 to anticipated child order
   → Session marked as "pending child order" state

3. Child Order Arrival
   → MostroService receives new-order message for child order
   → Session exists for trade key index 8
   → Message decrypted and processed successfully
   → Child order appears in "My Trades"

4. Child Order Management
   → OrderNotifier created for child order
   → Session enables full order lifecycle management
   → User can manage child order like any other order
```

### Pre-emptive Child Order Session Creation

#### 1. Enhanced Session Model

The `Session` model includes support for child orders:

```dart
// lib/data/models/session.dart
class Session {
  final NostrKeyPairs masterKey;
  final NostrKeyPairs tradeKey;
  final int keyIndex;
  final bool fullPrivacy;
  final DateTime startTime;
  String? orderId;
  String? parentOrderId; // For child orders, reference to parent order
  Role? role;
  // ...
}
```

#### 2. SessionNotifier Child Order Methods

Two new methods were added to `SessionNotifier`:

```dart
// lib/shared/notifiers/session_notifier.dart

/// Create a session for a child order using pre-generated trade key
Future<Session> createChildOrderSession({
  required NostrKeyPairs tradeKey,
  required int keyIndex,
  required String parentOrderId,
  required Role role,
}) async {
  final masterKey = ref.read(keyManagerProvider).masterKeyPair!;

  final session = Session(
    startTime: DateTime.now(),
    masterKey: masterKey,
    keyIndex: keyIndex,
    tradeKey: tradeKey,
    fullPrivacy: _settings.fullPrivacyMode,
    parentOrderId: parentOrderId,
    role: role, // Inherit role from parent order
  );

  // Add to state but don't assign orderId yet
  state = [...sessions, session];
  return session;
}

/// Link a child order session to its assigned order ID
Future<void> linkChildSessionToOrderId(String childOrderId, String tradeKeyPublic) async {
  final sessionIndex = state.indexWhere((s) =>
    s.tradeKey.public == tradeKeyPublic && s.orderId == null && s.parentOrderId != null
  );

  if (sessionIndex != -1) {
    final session = state[sessionIndex];
    session.orderId = childOrderId;
    _sessions[childOrderId] = session;
    await _storage.putSession(session);
    state = sessions;
  }
}
```

#### 3. MostroService FiatSent and Release

`MostroService.releaseOrder()` and `MostroService.sendFiatSent()` share the same helper. Both call `_prepareChildOrderIfNeeded(...)`, and only when that helper returns a `NextTrade` payload (meaning another child order is still possible) do they include it in the outgoing DM:

```dart
final payload = await _prepareChildOrderIfNeeded(
  orderId,
  callerLabel: 'release', // or 'fiatSent'
);

await publishOrder(
  MostroMessage(
    action: Action.release,
    id: orderId,
    payload: payload, // null when no child order should be created
  ),
);
```

#### 4. Child Order Message Handling

When the child order finally arrives, the linking happens directly inside the service that decrypted it. This keeps the flow simple and ensures "My Trades" is updated before any UI code reacts:

```dart
Future<void> _maybeLinkChildOrder(MostroMessage message, Session session) async {
  if (message.action != Action.newOrder || message.id == null) return;
  if (session.orderId != null || session.parentOrderId == null) return;

  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  await sessionNotifier.linkChildSessionToOrderId(
    message.id!,
    session.tradeKey.public,
  );

  ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
}
```

### Implemented Code Flow Analysis

The final flow:

```
1. releaseOrder()
   ├─ Detects range order
   ├─ Derives next trade key/index
   ├─ Prepares child session tied to the parent order
   └─ Sends release DM carrying NextTrade payload

2. _onData()
   ├─ Decrypts `Action.newOrder` from mostrod
   ├─ Finds the pre-created session by trade key
   └─ Delegates to _maybeLinkChildOrder()

3. _maybeLinkChildOrder()
   ├─ Links session to real child order id and persists it
   ├─ Spins up OrderNotifier so existing flows (timeouts, chat, etc.) attach
   └─ Child order shows in "My Trades" with maker role preserved
```

This arrangement keeps the responsibilities narrow: the service that created the child session is also responsible for linking it, while UI-facing notifiers remain unchanged.

### Key Index Synchronization

The child order implementation must maintain proper key index synchronization:

#### Parent-Child Key Relationship

```
Parent Order:
  - Order ID: "parent-order-123"
  - Key Index: 7
  - Trade Key: "02a1b2c3d4..." (index 7)

Child Order:
  - Order ID: "child-order-456" (assigned by mostrod)
  - Key Index: 8 (pre-generated during release)
  - Trade Key: "05z8y7x6w5..." (index 8)
  - Parent: "parent-order-123"
```

#### Key Manager State Management

```dart
// During release - current implementation
final nextKeyIndex = await keyManager.getNextKeyIndex(); // 8
final nextTradeKey = await keyManager.deriveTradeKeyFromIndex(nextKeyIndex);

// What's missing: Session creation for the generated key
// The key exists but no session maps to it

// Required: Session that maps trade key index 8 to anticipated child order
```

### Actual Implementation Code

Here are the actual working code implementations:

#### 1. Enhanced Session Model

```dart
// lib/data/models/session.dart
class Session {
  final NostrKeyPairs masterKey;
  final NostrKeyPairs tradeKey;
  final int keyIndex;
  final bool fullPrivacy;
  final DateTime startTime;
  String? orderId;
  String? parentOrderId; // For child orders, reference to parent order
  Role? role;
  // ... other fields

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.parentOrderId,
    this.role,
    Peer? peer,
  }) {
    // ... constructor body
  }

  Map<String, dynamic> toJson() => {
        'trade_key': tradeKey.public,
        'key_index': keyIndex,
        'full_privacy': fullPrivacy,
        'start_time': startTime.toIso8601String(),
        'order_id': orderId,
        'parent_order_id': parentOrderId,
        'role': role?.value,
        'peer': peer?.publicKey,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    // ... validation code
    return Session(
      masterKey: masterKeyValue,
      tradeKey: tradeKeyValue,
      keyIndex: keyIndex,
      fullPrivacy: fullPrivacy,
      startTime: startTime,
      orderId: json['order_id']?.toString(),
      parentOrderId: json['parent_order_id']?.toString(),
      role: role,
      peer: peer,
    );
  }
}
```

#### 2. SessionNotifier Child Order Methods

```dart
// lib/shared/notifiers/session_notifier.dart

/// Create a session for a child order using pre-generated trade key
/// This method is called during range order release to prepare for the incoming child order
Future<Session> createChildOrderSession({
  required NostrKeyPairs tradeKey,
  required int keyIndex,
  required String parentOrderId,
  required Role role,
}) async {
  final masterKey = ref.read(keyManagerProvider).masterKeyPair!;

  final session = Session(
    startTime: DateTime.now(),
    masterKey: masterKey,
    keyIndex: keyIndex,
    tradeKey: tradeKey,
    fullPrivacy: _settings.fullPrivacyMode,
    parentOrderId: parentOrderId,
    role: role,
  );

  _pendingChildSessions[tradeKey.public] = session;
  _emitState();

  _logger.i(
    'Prepared child session for parent order $parentOrderId using key index $keyIndex',
  );

  return session;
}

/// Link a child order session to its assigned order ID when the order message arrives
Future<void> linkChildSessionToOrderId(String childOrderId, String tradeKeyPublic) async {
  final session = _pendingChildSessions.remove(tradeKeyPublic);
  if (session == null) {
    _logger.w(
      'No pending child session found for trade key $tradeKeyPublic; nothing to link.',
    );
    return;
  }

  session.orderId = childOrderId;
  _sessions[childOrderId] = session;
  await _storage.putSession(session);
  _emitState();

  _logger.i(
    'Linked child order $childOrderId to prepared session (parent: ${session.parentOrderId})',
  );
}
```

#### 3. MostroService Pre-emptive Child Session Creation

```dart
Future<void> releaseOrder(String orderId) async {
  final payload = await _prepareChildOrderIfNeeded(
    orderId,
    callerLabel: 'release',
  );

  await publishOrder(
    MostroMessage(
      action: Action.release,
      id: orderId,
      payload: payload,
    ),
  );
}

Future<void> sendFiatSent(String orderId) async {
  final payload = await _prepareChildOrderIfNeeded(
    orderId,
    callerLabel: 'fiatSent',
  );

  await publishOrder(
    MostroMessage(
      action: Action.fiatSent,
      id: orderId,
      payload: payload,
    ),
  );
}
```

```dart
Future<Payload?> _prepareChildOrderIfNeeded(
  String orderId, {
  required String callerLabel,
}) async {
  final order = ref.read(orderNotifierProvider(orderId)).order;
  if (order?.minAmount == null ||
      order?.maxAmount == null ||
      order!.minAmount! >= order.maxAmount!) {
    return null;
  }

  final minAmount = order.minAmount!;
  final maxAmount = order.maxAmount!;
  final selectedAmount = order.fiatAmount;
  final remaining = maxAmount - selectedAmount;

  if (remaining < minAmount) {
    _logger.i(
      '[$callerLabel] Range order $orderId exhausted (remaining $remaining < min $minAmount); child order skipped.',
    );
    return null;
  }

  final keyManager = ref.read(keyManagerProvider);
  final nextKeyIndex = await keyManager.getNextKeyIndex();
  final nextTradeKey = await keyManager.deriveTradeKeyFromIndex(nextKeyIndex);

  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  final currentSession = sessionNotifier.getSessionByOrderId(orderId);
  if (currentSession != null && currentSession.role != null) {
    await sessionNotifier.createChildOrderSession(
      tradeKey: nextTradeKey,
      keyIndex: nextKeyIndex,
      parentOrderId: orderId,
      role: currentSession.role!,
    );
    _logger.i(
      '[$callerLabel] Prepared child session for $orderId using key index $nextKeyIndex',
    );
  } else {
    _logger.w(
      '[$callerLabel] Unable to prepare child session for $orderId; session or role missing.',
    );
  }

  return NextTrade(
    key: nextTradeKey.public,
    index: nextKeyIndex,
  );
}
```

#### 4. Child Order Linking inside `MostroService`

```dart
Future<void> _maybeLinkChildOrder(
  MostroMessage message,
  Session session,
) async {
  if (message.action != Action.newOrder || message.id == null) return;
  if (session.orderId != null || session.parentOrderId == null) return;

  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  await sessionNotifier.linkChildSessionToOrderId(
    message.id!,
    session.tradeKey.public,
  );

  ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
}
```

### Complete Working Flow Analysis

With the implemented solution, the complete child order flow works as follows:

#### 1. Range Order Trigger (`MostroService._prepareChildOrderIfNeeded`)
```
User completes range order (orderId: "parent-123", keyIndex: 7)
├─ System detects range order (minAmount < maxAmount) ✅
├─ KeyManager.getNextKeyIndex() returns 8 ✅
├─ KeyManager.deriveTradeKeyFromIndex(8) generates trade key ✅
├─ _prepareChildOrderIfNeeded() stores pending child session (unless remainder < min) ✅
│  ├─ tradeKey: new trade key (index 8)
│  ├─ parentOrderId: "parent-123"
│  └─ role: inherited from parent (e.g., seller)
└─ Release/fiat-sent DM includes NextTrade only when helper returned payload ✅
```

#### 2. Child Order Message Reception (`MostroService._onData` + `_maybeLinkChildOrder`)
```
Mostrod creates child order with ID "child-456"
├─ DM arrives encrypted to trade key index 8 ✅
├─ MostroService._onData() decrypts it ✅
├─ Prepared session (orderId == null, parentOrderId == parent-123) found ✅
├─ _maybeLinkChildOrder() persists the child session with id "child-456" ✅
└─ OrderNotifier for "child-456" spun up to drive UI + timeouts ✅
```

### Key Technical Implementation Details

#### Subscription Management
No extra calls are required. By pushing the pending child session into the
Riverpod state, `SubscriptionManager` sees the new trade key automatically and
rebuilds the `p` filters the next time it reacts to the provider change.

#### Session State Management
Child sessions have a unique lifecycle:
1. **Creation**: `orderId = null, parentOrderId = "parent-123"`
2. **Linking**: `orderId = "child-456", parentOrderId = "parent-123"`
3. **Active**: Full order management capabilities enabled

#### Role Inheritance Logic
```dart
// Parent order role determination
final parentRole = currentSession!.role!; // e.g., Role.seller

// Child inherits exact same role
final childSession = Session(
  role: parentRole, // Child is also Role.seller
  parentOrderId: orderId, // Links to parent
  // ... other fields
);
```

## Code Flow Examples

### Complete Order Creation Flow with Key Logging

```dart
// File: lib/features/order/notfiers/add_order_notifier.dart:71-85
Future<void> submitOrder(Order order) async {
  logger.d('=== ORDER CREATION START ===');
  
  // Generate unique request ID for tracking
  final message = MostroMessage<Order>(
    action: Action.newOrder,
    id: null,
    requestId: requestId,  // Generated from order UUID + timestamp
    payload: order,
  );
  logger.d('Request ID: $requestId');
  
  // Create session with fresh cryptographic context
  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  session = await sessionNotifier.newSession(
    requestId: requestId,
    role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
  );
  
  logger.d('Session created:');
  logger.d('  - Identity key (index 0): ${session.masterKey.public}');
  logger.d('  - Trade key (index ${session.keyIndex}): ${session.tradeKey.public}');
  logger.d('  - Full privacy: ${session.fullPrivacy}');
  
  // Submit to Mostro service for wrapping and transmission
  await mostroService.submitOrder(message);
  state = state.updateWith(message);
}
```

### Session Creation with Key Derivation Logging

```dart
// File: lib/shared/notifiers/session_notifier.dart:73-100
Future<Session> newSession({String? orderId, int? requestId, Role? role}) async {
  logger.d('=== SESSION CREATION START ===');
  
  // Get identity key (always index 0)
  final masterKey = ref.read(keyManagerProvider).masterKeyPair!;
  logger.d('Identity key (m/44\'/1237\'/38383\'/0/0): ${masterKey.public}');
  
  // Get current trade key index and derive new trade key
  final keyIndex = await ref.read(keyManagerProvider).getCurrentKeyIndex();
  logger.d('Current trade key index: $keyIndex');
  
  final tradeKey = await ref.read(keyManagerProvider).deriveTradeKey();
  logger.d('Derived trade key (m/44\'/1237\'/38383\'/0/$keyIndex): ${tradeKey.public}');
  
  // Create session with all cryptographic context
  final session = Session(
    startTime: DateTime.now(),
    masterKey: masterKey,      // For reputation and seal signing
    keyIndex: keyIndex,        // For protocol trade_index field
    tradeKey: tradeKey,        // For rumor signing and decryption
    fullPrivacy: _settings.fullPrivacyMode,
    orderId: orderId,
    role: role,
  );
  
  // Store session for message routing
  if (orderId != null) {
    _sessions[orderId] = session;
    logger.d('Session stored with order ID: $orderId');
  } else if (requestId != null) {
    _requestIdToSession[requestId] = session;
    logger.d('Temporary session stored with request ID: $requestId');
  }
  
  logger.d('=== SESSION CREATION COMPLETE ===');
  return session;
}
```

### Message Decryption and Processing

```dart
// File: lib/services/mostro_service.dart:44-82
Future<void> _onData(NostrEvent event) async {
  logger.d('=== INCOMING MESSAGE PROCESSING ===');
  logger.d('Event ID: ${event.id}');
  logger.d('Recipient (trade key): ${event.recipient}');
  
  // Find session by trade key public
  final sessions = ref.read(sessionNotifierProvider);
  final matchingSession = sessions.firstWhereOrNull(
    (s) => s.tradeKey.public == event.recipient,
  );
  
  if (matchingSession == null) {
    logger.w('No matching session found for recipient: ${event.recipient}');
    return;
  }
  
  logger.d('Matched session:');
  logger.d('  - Order ID: ${matchingSession.orderId}');
  logger.d('  - Key index: ${matchingSession.keyIndex}');
  logger.d('  - Role: ${matchingSession.role}');
  
  // Decrypt gift wrap using trade key private
  final privateKey = matchingSession.tradeKey.private;
  logger.d('Decrypting with trade key private: [REDACTED]');
  
  try {
    final decryptedEvent = await event.unWrap(privateKey);
    if (decryptedEvent.content == null) return;
    
    // Parse Mostro message
    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List) return;
    
    final msg = MostroMessage.fromJson(result[0]);
    logger.d('Decrypted message:');
    logger.d('  - Action: ${msg.action}');
    logger.d('  - Order ID: ${msg.id}');
    logger.d('  - Trade index: ${msg.tradeIndex}');
    
    // Store message for processing
    final messageStorage = ref.read(mostroStorageProvider);
    await messageStorage.addMessage(decryptedEvent.id!, msg);
    
    logger.d('=== MESSAGE PROCESSING COMPLETE ===');
  } catch (e) {
    logger.e('Error processing event', error: e);
  }
}
```

## Conclusion

The Mostro mobile app implements a sophisticated hierarchical key management system that balances security, privacy, and usability. The system provides:

- **Cryptographic Isolation**: Each trade uses a unique key pair
- **Reputation Management**: Optional identity key for reputation tracking  
- **Privacy Options**: Full privacy mode for anonymous trading
- **Secure Storage**: Proper separation of sensitive and non-sensitive data
- **Session Management**: Comprehensive session lifecycle management
- **Protocol Compliance**: Full NIP-59 gift wrap implementation

This architecture ensures that user funds and privacy are protected while maintaining the ability to build reputation and participate in the Mostro peer-to-peer trading network.

*Last updated: September 15, 2025*  
*Protocol version: 1.0*  
