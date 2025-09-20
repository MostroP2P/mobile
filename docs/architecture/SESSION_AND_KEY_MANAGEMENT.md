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
- **Cleanup**: Automatic cleanup of expired sessions (24 hours default)

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

#### 3. MostroService Release Enhancement

`MostroService.releaseOrder()` now prepares the child session before it asks mostrod to spawn the follow-up range order:

```dart
if (isRangeOrder) {
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
  } else {
    _logger.w('Release invoked for $orderId but maker role missing');
  }

  payload = NextTrade(key: nextTradeKey.public, index: nextKeyIndex);
}
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

The final flow is now:

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
  String? parentOrderId; // NEW: For child orders, reference to parent order
  Role? role;
  // ... other fields

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.parentOrderId, // NEW: Added to constructor
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
        'parent_order_id': parentOrderId, // NEW: Added to JSON serialization
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
      parentOrderId: json['parent_order_id']?.toString(), // NEW: Added from JSON
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
    parentOrderId: parentOrderId, // Link to parent order
    role: role, // Inherit role from parent order
  );

  // Add to state but don't assign orderId yet (will be set when order arrives)
  state = [...sessions, session];

  _logger.i('Created child order session for parent order: $parentOrderId');
  _logger.i('Child trade key index: $keyIndex, public: ${tradeKey.public}');
  _logger.i('Child will inherit role: ${role.value}');

  return session;
}

/// Link a child order session to its assigned order ID when the order message arrives
Future<void> linkChildSessionToOrderId(String childOrderId, String tradeKeyPublic) async {
  final sessionIndex = state.indexWhere((s) =>
    s.tradeKey.public == tradeKeyPublic &&
    s.orderId == null &&
    s.parentOrderId != null
  );

  if (sessionIndex != -1) {
    final session = state[sessionIndex];
    session.orderId = childOrderId;
    _sessions[childOrderId] = session;
    await _storage.putSession(session);
    state = sessions;

    _logger.i('Successfully linked child order $childOrderId to existing session');
    _logger.i('Parent order: ${session.parentOrderId}, Role: ${session.role?.value}');
  } else {
    _logger.w('Could not find child session to link for order: $childOrderId');
  }
}
```

#### 3. MostroService Pre-emptive Child Session Creation

```dart
// lib/services/mostro_service.dart - Enhanced releaseOrder method
Future<void> releaseOrder(String orderId) async {
  // Get the current order state to check if it's a range order
  final orderState = ref.read(orderNotifierProvider(orderId));
  final order = orderState.order;

  // Check if this is a range order (has min and max amounts that are different and valid)
  final isRangeOrder = order?.minAmount != null &&
      order?.maxAmount != null &&
      order!.minAmount! < order.maxAmount!;

  Payload? payload;

  if (isRangeOrder) {
    // For range orders, we need to generate the next trade key and index
    final keyManager = ref.read(keyManagerProvider);
    final nextKeyIndex = await keyManager.getNextKeyIndex();
    final nextTradeKey = await keyManager.deriveTradeKeyFromIndex(nextKeyIndex);

    // Get the current session to inherit the role for the child order
    final currentSession = ref.read(sessionNotifierProvider.notifier).getSessionByOrderId(orderId);
    if (currentSession?.role != null) {
      // CREATE SESSION FOR ANTICIPATED CHILD ORDER
      // This ensures that when mostrod creates the child order and sends the new-order message,
      // our app will have a session ready to receive and process it
      final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
      await sessionNotifier.createChildOrderSession(
        tradeKey: nextTradeKey,
        keyIndex: nextKeyIndex,
        parentOrderId: orderId,
        role: currentSession!.role!, // Inherit role from parent
      );

      _logger.i('Created child order session for range order $orderId');
      _logger.i('Child trade key index: $nextKeyIndex, public: ${nextTradeKey.public}');
    } else {
      _logger.w('Cannot create child session: parent session or role not found for $orderId');
    }

    payload = NextTrade(
      key: nextTradeKey.public,
      index: nextKeyIndex,
    );
  }

  await publishOrder(
    MostroMessage(
      action: Action.release,
      id: orderId,
      payload: payload,
    ),
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

### Implementation Summary

The implemented solution provides:

1. **Timing Predictability**: Session exists before child order message arrives
2. **Key Index Consistency**: Maintains proper parent-child key relationship
3. **Role Inheritance**: Child orders automatically inherit parent order role
4. **Full Order Management**: Child orders support complete lifecycle management
5. **Robust Error Handling**: Comprehensive logging and error recovery

#### Logging for Debugging

The implementation includes detailed logging to help track child order processing:

```
I/flutter: Created child order session for range order parent-123
I/flutter: Child trade key index: 8, public: 05z8y7x6w5...
I/flutter: Child will inherit role: seller
I/flutter: Successfully linked child order child-456 to existing session
I/flutter: Parent order: parent-123, Role: seller
```

This ensures child orders from range order releases are properly recognized and managed by the app.

### Complete Working Flow Analysis

With the implemented solution, the complete child order flow now works as follows:

#### 1. Range Order Release Trigger (`MostroService.releaseOrder`)
```
User completes range order (orderId: "parent-123", keyIndex: 7)
├─ System detects range order (minAmount < maxAmount) ✅
├─ KeyManager.getNextKeyIndex() returns 8 ✅
├─ KeyManager.deriveTradeKeyFromIndex(8) generates trade key ✅
├─ SessionNotifier.createChildOrderSession() remembers the child ✅
│  ├─ tradeKey: new trade key (index 8)
│  ├─ parentOrderId: "parent-123"
│  └─ role: inherited from parent (e.g., seller)
└─ NextTrade payload sent with new trade key ✅
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

#### Error Handling and Logging
Comprehensive logging enables debugging:
```
I/flutter: Created child order session for parent order: parent-123
I/flutter: Child trade key index: 8, public: 05z8y7x6w5...
I/flutter: Child will inherit role: seller
I/flutter: Successfully linked child order child-456 to existing session
I/flutter: Parent order: parent-123, Role: seller
```

### Troubleshooting Child Order Issues

#### Problem: Child order message not received
- **Check**: `_maybeLinkChildOrder` logs appear in the console
- **Solution**: Ensure the maker released the range order locally so the child
  session was prepared before mostrod broadcast the follow-up order

#### Problem: Child order not appearing in "My Trades"
- **Check**: Session storage now contains the child order id
- **Solution**: Confirm `linkChildSessionToOrderId` executed (search for the
  "Linked child order" log) and that no errors surfaced while persisting

#### Problem: Session linking fails
- **Check**: Trade key matching between session and message
- **Solution**: Verify child session creation used correct trade key
- **Debug**: Look for "No pending child session found" warning

#### Problem: Role inheritance incorrect
- **Check**: Parent session role availability during release
- **Solution**: Ensure parent session exists and has role set
- **Debug**: Look for "Release invoked ... but session role missing" warning

This implementation ensures that child orders from range order releases work seamlessly, appearing in "My Trades" with full functionality and proper parent-child relationship tracking.

## Specific Scenarios

### Scenario 1: New Order Creation

#### Flow Description
User creates a new buy/sell order through the app interface.

#### Key Usage Log
```
1. User initiates order creation
   → App generates requestId: 1234567890
   → KeyManager.getCurrentKeyIndex() returns: 5
   → KeyManager.deriveTradeKey() generates trade key at index 5
   → Trade key public: 02a1b2c3d4...
   → KeyManager increments index to 6

2. SessionNotifier.newSession() creates session
   → masterKey (identity): 03e5f6g7h8... (index 0)
   → tradeKey: 02a1b2c3d4... (index 5)
   → keyIndex: 5
   → fullPrivacy: false
   → requestId: 1234567890

3. MostroMessage creation
   → action: new-order
   → tradeIndex: 5
   → payload: Order{kind: buy, fiatAmount: 100, ...}

4. Gift wrap process (MostroMessage.wrap())
   → Rumor: signed by trade key (02a1b2c3d4...)
   → Seal: signed by identity key (03e5f6g7h8...)
   → Wrapper: signed by ephemeral key (04i9j0k1l2...)

5. Message sent to mostrod
   → Event kind: 1059 (gift wrap)
   → Recipient: mostro pubkey
```

#### Code Flow
```dart
// 1. Order creation triggered
AddOrderNotifier.submitOrder() {
  // 2. Session creation with key derivation  
  session = await sessionNotifier.newSession(requestId: requestId, role: Role.buyer);
  
  // 3. Message wrapping and transmission
  await mostroService.submitOrder(message);
}

// 4. Mostrod response handling
AddOrderNotifier._confirmOrder() {
  session.orderId = message.id;  // Link session to confirmed order
  sessionNotifier.saveSession(session);  // Persist with order ID
}
```

### Scenario 2: Mostrod Order Confirmation

#### Flow Description
Mostrod confirms the new order creation and assigns an order ID.

#### Key Usage Log
```
1. Mostrod processes new-order request
   → Validates gift wrap layers
   → Creates order with ID: "12ab34cd-56ef-78gh-90ij-klmnopqrstuv"

2. Mostrod sends confirmation
   → action: new-order
   → id: "12ab34cd-56ef-78gh-90ij-klmnopqrstuv" 
   → payload: Order{id: "12ab34cd...", status: pending, ...}
   → Encrypted to trade key: 02a1b2c3d4...

3. App receives and processes confirmation
   → MostroService._onData() decrypts message
   → Uses trade key private: [REDACTED] for decryption
   → AddOrderNotifier._confirmOrder() updates session
   → Session.orderId = "12ab34cd-56ef-78gh-90ij-klmnopqrstuv"

4. Session persistence
   → SessionStorage.putSession() stores complete session
   → Database entry: {orderId: "12ab34cd...", keyIndex: 5, tradeKey: "02a1b2c3d4...", ...}
```

### Scenario 3: Range Order Child Creation

#### Flow Description
When a range order is successfully completed, mostrod creates a child order using the next available trade key.

#### Key Usage Log
```
1. Range order completion (release action)
   → Current session: keyIndex 7, orderId "parent-order-123"
   → KeyManager.getNextKeyIndex() returns: 8
   → KeyManager.deriveTradeKeyFromIndex(8) generates: 05z8y7x6w5...

2. Release message preparation  
   → action: release
   → payload: NextTrade{key: "05z8y7x6w5...", index: 8}
   → Sent with current session keys (index 7)

3. Mostrod processes release
   → Creates child order with new trade key
   → Child order ID: "child-order-456"
   → Maps child order to trade key: 05z8y7x6w5... (index 8)

4. Child order notification
   → action: new-order  
   → id: "child-order-456"
   → Encrypted to next trade key: 05z8y7x6w5...
   → App decrypts using key index 8 private key

5. Session management
   → New session created for child order
   → Parent session remains active until completion
   → KeyManager index now at 9 for next trade
```

#### Range Order Release Code (`lib/services/mostro_service.dart:153-185`)
```dart
Future<void> releaseOrder(String orderId) async {
  final orderState = ref.read(orderNotifierProvider(orderId));
  final order = orderState.order;
  
  // Check if this is a range order
  final isRangeOrder = order?.minAmount != null &&
      order?.maxAmount != null &&
      order!.minAmount! < order.maxAmount!;
  
  Payload? payload;
  
  if (isRangeOrder) {
    // Generate next trade key for child order
    final keyManager = ref.read(keyManagerProvider);
    final nextKeyIndex = await keyManager.getNextKeyIndex();  // Increment and return new index
    final nextTradeKey = await keyManager.deriveTradeKeyFromIndex(nextKeyIndex);
    
    // Create NextTrade payload with new key information
    payload = NextTrade(
      key: nextTradeKey.public,  // Public key for child order
      index: nextKeyIndex,       // Index for child order
    );
  }
  
  await publishOrder(
    MostroMessage(
      action: Action.release,
      id: orderId,
      payload: payload,  // null for regular orders, NextTrade for range orders
    ),
  );
}
```

### Scenario 4: Full Privacy Mode Operation

#### Flow Description
User operates in full privacy mode where identity keys are never shared with mostrod.

#### Key Usage Log
```
1. User enables full privacy mode
   → Settings.fullPrivacyMode = true
   → No reputation tracking possible

2. Order creation in full privacy mode
   → Session creation: fullPrivacy = true
   → masterKey still generated (for local use)
   → tradeKey: 06u5t4s3r2... (index 3)

3. Gift wrap process (full privacy)
   → Rumor: NO signature included
   → Seal: signed by TRADE key (06u5t4s3r2...) instead of identity key
   → Wrapper: signed by ephemeral key (07q1p0o9n8...)

4. Message structure difference
   Standard mode: [message, trade_key_signature]  
   Full privacy: [message, null]

5. Mostrod processing
   → Cannot link orders to identity
   → No reputation tracking
   → Order processed anonymously
```

#### Full Privacy Wrapping Logic
```dart
Future<NostrEvent> wrap({required NostrKeyPairs tradeKey, ...}) async {
  final keySet = masterKey ?? tradeKey;  // Use tradeKey if no masterKey (full privacy)
  
  // In full privacy: masterKey is null, so keySet = tradeKey
  // Seal will be signed by tradeKey instead of identity key
  final sealedContent = await NostrUtils.createSeal(
    keySet,  // tradeKey in full privacy mode
    wrapperKeyPair.private,
    recipientPubKey,
    encryptedContent
  );
}
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

## Logging and Debugging

### Key Logging Points

The application logs key operations at several critical points:

#### 1. Key Derivation Logging
```dart
// In KeyManager.deriveTradeKey()
logger.d('Deriving trade key at index: $currentIndex');
logger.d('Derived public key: ${keyPair.public}');
logger.d('Incrementing index to: ${currentIndex + 1}');
```

#### 2. Session Management Logging  
```dart
// In SessionNotifier
logger.d('Creating session with identity key: ${masterKey.public}');
logger.d('Trade key index: $keyIndex, public: ${tradeKey.public}');
logger.d('Full privacy mode: $fullPrivacy');
```

#### 3. Message Wrapping Logging
```dart
// In MostroService.publishOrder()
logger.i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
logger.d('Using trade key: ${session.tradeKey.public}');
logger.d('Using identity key: ${session.masterKey?.public ?? "FULL_PRIVACY_MODE"}');
```

#### 4. Message Processing Logging
```dart
// In MostroService._onData()
logger.i('Received DM, Event ID: ${decryptedEvent.id} with payload: ${decryptedEvent.content}');
logger.d('Matched trade key: ${matchingSession.tradeKey.public}');
```

### Debug Configuration

To enable comprehensive key logging, ensure proper logger configuration:

```dart
// In main application setup
final logger = Logger(
  printer: PrettyPrinter(
    methodCount: 2,
    errorMethodCount: 8,
    lineLength: 120,
    colors: true,
    printEmojis: true,
    printTime: true,
  ),
  level: Level.debug,  // Enable debug logging
);
```

### Security Considerations

⚠️ **IMPORTANT**: Private keys should never be logged in production:

```dart
// ✅ Safe logging (public keys only)
logger.d('Trade key public: ${tradeKey.public}');
logger.d('Identity key public: ${masterKey.public}');

// ❌ NEVER log private keys
logger.d('Private key: ${tradeKey.private}');  // SECURITY RISK

// ✅ Safe private key reference
logger.d('Decrypting with trade key private: [REDACTED]');
```

### Troubleshooting Common Issues

#### Issue: "No matching session found"
- **Cause**: Message received for unknown trade key
- **Debug**: Check session creation and key derivation logs
- **Solution**: Verify session persistence and trade key management

#### Issue: "Failed to decrypt NIP-59 event"  
- **Cause**: Wrong private key used for decryption
- **Debug**: Compare recipient pubkey with session trade key
- **Solution**: Ensure correct session-to-key mapping

#### Issue: "Invalid trade_index format"
- **Cause**: Trade index mismatch between app and mostrod
- **Debug**: Check key index incrementation and persistence
- **Solution**: Verify KeyManager index management

## Conclusion

The Mostro mobile app implements a sophisticated hierarchical key management system that balances security, privacy, and usability. The system provides:

- **Cryptographic Isolation**: Each trade uses a unique key pair
- **Reputation Management**: Optional identity key for reputation tracking  
- **Privacy Options**: Full privacy mode for anonymous trading
- **Secure Storage**: Proper separation of sensitive and non-sensitive data
- **Session Management**: Comprehensive session lifecycle management
- **Protocol Compliance**: Full NIP-59 gift wrap implementation

This architecture ensures that user funds and privacy are protected while maintaining the ability to build reputation and participate in the Mostro peer-to-peer trading network.

