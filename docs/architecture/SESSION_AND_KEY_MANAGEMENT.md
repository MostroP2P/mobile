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

---

*Last updated: September 15, 2025*  
*Protocol version: 1.0*  
*Key derivation path: m/44'/1237'/38383'/0/N*