# Order Creation Process in Mostro Mobile App

## Overview

This document provides a detailed explanation of how order creation works in the Mostro mobile application. The process involves creating sell/buy orders, sending them to the Mostro network, receiving confirmation messages, and updating the application state accordingly.

## Architecture Components

### Key Files and Classes

- **`lib/services/mostro_service.dart`** - Main service for Mostro communication
- **`lib/features/order/notfiers/order_notifier.dart`** - Manages order state and lifecycle
- **`lib/features/order/notfiers/abstract_mostro_notifier.dart`** - Base class for Mostro message handling
- **`lib/data/repositories/mostro_storage.dart`** - Local storage for Mostro messages
- **`lib/features/order/models/order_state.dart`** - Order state management
- **`lib/shared/providers/mostro_storage_provider.dart`** - Riverpod providers for message streams

## Complete Order Creation Flow

### 1. User Initiates Order Creation

The user creates an order through the UI (sell or buy order). This typically happens in order creation screens that collect:
- Order type (sell/buy)
- Fiat amount
- Payment methods
- Premium percentage
- Other order parameters

**Code Reference**: `lib/features/order/screens/add_order_screen.dart`

### 2. Order Submission and Session Creation

When the user submits the order, the `AddOrderNotifier` handles the complete flow:

```dart
// lib/features/order/notfiers/add_order_notifier.dart:71-85
Future<void> submitOrder(Order order) async {
  // 1. Create MostroMessage with new-order action
  final message = MostroMessage<Order>(
    action: Action.newOrder,
    id: null,                    // Will be assigned by mostrod
    requestId: requestId,        // Unique request identifier
    payload: order,
  );
  
  // 2. Create new session with fresh trade key
  final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
  session = await sessionNotifier.newSession(
    requestId: requestId,
    role: order.kind == OrderType.buy ? Role.buyer : Role.seller,
  );
  
  // 3. Send wrapped message to mostrod
  await mostroService.submitOrder(message);
  state = state.updateWith(message);
}
```

**Key Steps**:
1. **Message Creation**: Creates `MostroMessage` with `Action.newOrder` and order payload
2. **Session Creation**: Creates new session with fresh trade key for this order
3. **Message Submission**: Sends the message to MostroService for processing

### 3. Message Encryption and Publishing

The order message is processed through the `publishOrder` method in `MostroService`:

```dart
// lib/services/mostro_service.dart:206-218
Future<void> publishOrder(MostroMessage order) async {
  // 1. Retrieve session by requestId
  final session = await _getSession(order);

  // 2. Create NIP-59 gift wrap with session keys
  final event = await order.wrap(
    tradeKey: session.tradeKey,              // Trade key for rumor
    recipientPubKey: _settings.mostroPublicKey,
    masterKey: session.fullPrivacy ? null : session.masterKey,  // Identity key for seal (if not full privacy)
    keyIndex: session.fullPrivacy ? null : session.keyIndex,    // Trade index for protocol
  );
  
  _logger.i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
  
  // 3. Publish encrypted event to Nostr relays
  await ref.read(nostrServiceProvider).publishEvent(event);
}
```

**Message Structure Sent to Mostrod**:
```json
{
  "order": {
    "version": 1,
    "action": "new-order",
    "request_id": "unique-request-id",
    "trade_index": 1,
    "payload": {
      "order": {
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "USD",
        "min_amount": null,
        "max_amount": null,
        "fiat_amount": 100,
        "payment_method": "Lightning",
        "premium": 1,
        "created_at": 0
      }
    }
  }
}
```

**Key Steps**:
1. **Session Retrieval**: Gets the current session for the order using `requestId`
2. **Message Wrapping**: Encrypts the message using NIP-59 (Gift wrap) with the trade key
3. **Event Publishing**: Sends the encrypted event to Mostro via Nostr relays

### 4. Mostro Network Processing

Mostro receives the encrypted order message and:
1. **Decrypts** the message using the trade key
2. **Validates** the order parameters
3. **Generates** a unique order ID
4. **Publishes** the order as a public NIP-69 event (kind 38383)
5. **Sends** a confirmation message back to the user's trade key

### 5. Confirmation Message Reception

The app continuously monitors for incoming messages through the `MostroService`:

```dart
// lib/services/mostro_service.dart:44-82
Future<void> _onData(NostrEvent event) async {
  // 1. Check for duplicate events
  final eventStore = ref.read(eventStorageProvider);
  if (await eventStore.hasItem(event.id!)) return;
  
  // 2. Store event metadata
  await eventStore.putItem(
    event.id!,
    {
      'id': event.id,
      'created_at': event.createdAt!.millisecondsSinceEpoch ~/ 1000,
    },
  );

  // 3. Find matching session by trade key
  final sessions = ref.read(sessionNotifierProvider);
  final matchingSession = sessions.firstWhereOrNull(
    (s) => s.tradeKey.public == event.recipient,
  );
  if (matchingSession == null) {
    _logger.w('No matching session found for recipient: ${event.recipient}');
    return;
  }
  
  // 4. Decrypt the message using trade key
  final privateKey = matchingSession.tradeKey.private;
  try {
    final decryptedEvent = await event.unWrap(privateKey);
    if (decryptedEvent.content == null) return;

    final result = jsonDecode(decryptedEvent.content!);
    if (result is! List) return;

    // 5. Parse and store the MostroMessage
    final msg = MostroMessage.fromJson(result[0]);
    final messageStorage = ref.read(mostroStorageProvider);
    await messageStorage.addMessage(decryptedEvent.id!, msg);
    
    _logger.i(
      'Received DM, Event ID: ${decryptedEvent.id} with payload: ${decryptedEvent.content}',
    );
  } catch (e) {
    _logger.e('Error processing event', error: e);
  }
}
```

**Key Steps**:
1. **Deduplication**: Prevents processing duplicate events
2. **Session Matching**: Finds the correct session using the trade key
3. **Decryption**: Unwraps the NIP-59 gift wrap using the trade key
4. **Message Storage**: Stores the decrypted MostroMessage locally
5. **Logging**: Logs the received message for debugging

### 6. Order Confirmation Handling

When Mostro sends the confirmation message back with the order ID, the `AddOrderNotifier` processes it:

```dart
// lib/features/order/notfiers/add_order_notifier.dart:28-58
@override
void subscribe() {
  subscription = ref.listen(
    addOrderEventsProvider(requestId),
    (_, next) {
      next.when(
        data: (msg) {
          if (msg != null) {
            if (msg.payload is Order) {
              if (msg.action == Action.newOrder) {
                _confirmOrder(msg);  // Handle confirmation
              } else {
                logger.i('AddOrderNotifier: received ${msg.action}');
              }
            } else if (msg.payload is CantDo) {
              handleEvent(msg);
              
              // Reset for retry if out_of_range_sats_amount
              final cantDo = msg.getPayload<CantDo>();
              if (cantDo?.cantDoReason == CantDoReason.outOfRangeSatsAmount) {
                _resetForRetry();
              }
            }
          }
        },
        error: (error, stack) => handleError(error, stack),
        loading: () {},
      );
    },
  );
}
```

**Confirmation Processing**:
```dart
// lib/features/order/notfiers/add_order_notifier.dart:60-69
Future<void> _confirmOrder(MostroMessage message) async {
  // 1. Update state with confirmed order
  state = state.updateWith(message);
  
  // 2. Link session to confirmed order ID
  session.orderId = message.id;
  
  // 3. Persist session with order ID
  ref.read(sessionNotifierProvider.notifier).saveSession(session);
  
  // 4. Create order-specific notifier for ongoing trade management
  ref.read(orderNotifierProvider(message.id!).notifier).subscribe();
  
  // 5. Navigate to confirmation screen
  ref.read(navigationProvider.notifier).go('/order_confirmed/${message.id!}');
  
  // 6. Clean up AddOrderNotifier
  ref.invalidateSelf();
}
```

**Key Steps in Confirmation**:
1. **State Update**: Updates the order state with the confirmed order data
2. **Session Linking**: Links the session to the confirmed order ID
3. **Session Persistence**: Saves the session to local storage
4. **Order Notifier Creation**: Creates a new `OrderNotifier` for ongoing trade management
5. **Navigation**: Navigates to the order confirmation screen
6. **Cleanup**: Invalidates the `AddOrderNotifier` as it's no longer needed

### 7. Confirmation Message Structure

The confirmation message from Mostro contains the order ID and full order details:

```json
{
  "order": {
    "version": 1,
    "id": "confirmed-order-id-12345",    // ← Order ID assigned by mostrod
    "action": "new-order",
    "request_id": "unique-request-id",   // ← Matches the original request
    "payload": {
      "order": {
        "id": "confirmed-order-id-12345", // ← Same order ID
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "USD",
        "fiat_amount": 100,
        "payment_method": "Lightning",
        "premium": 1,
        "created_at": 1698870173
      }
    }
  }
}
```

**Critical Elements**:
- **`id`**: The order ID assigned by Mostro (was `null` in the original request)
- **`request_id`**: Matches the original request ID for correlation
- **`action`**: Still `"new-order"` but now with confirmed order data
- **`payload.order`**: Contains the full order details with the assigned ID

### 8. Message Storage

The confirmation message is stored locally using `MostroStorage`:

```dart
// lib/data/repositories/mostro_storage.dart:13-30
Future<void> addMessage(String key, MostroMessage message) async {
  final id = key;
  try {
    if (await hasItem(id)) return;
    
    final Map<String, dynamic> dbMap = message.toJson();
    message.timestamp ??= DateTime.now().millisecondsSinceEpoch;
    dbMap['timestamp'] = message.timestamp;

    await store.record(id).put(db, dbMap);
    _logger.i('Saved message of type ${message.action} with order id ${message.id}');
  } catch (e, stack) {
    _logger.e('addMessage failed for $id', error: e, stackTrace: stack);
    rethrow;
  }
}
```

### 9. Order State Management

After confirmation, the `OrderNotifier` takes over for ongoing trade management:

```dart
// lib/features/order/notfiers/order_notifier.dart:15-25
class OrderNotifier extends AbstractMostroNotifier {
  late final MostroService mostroService;
  
  OrderNotifier(super.orderId, super.ref) {
    mostroService = ref.read(mostroServiceProvider);
    sync();
    subscribe();
    _subscribeToPublicEvents();
  }
}
```

**Purpose**: The `OrderNotifier` manages the order throughout its entire lifecycle after creation, handling:
- Trade progression (buyer taking order, payment requests, etc.)
- State updates from Mostro messages
- Public event monitoring for timeout detection
- UI updates and navigation

### 10. Message Stream Subscription

The notifier subscribes to message streams using Riverpod providers:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart:35-55
void subscribe() {
  subscription = ref.listen(
    mostroMessageStreamProvider(orderId),
    (_, next) {
      next.when(
        data: (MostroMessage? msg) {
          logger.i('Received message: ${msg?.toJson()}');
          if (msg != null) {
            if (mounted) {
              state = state.updateWith(msg);
            }
            if (msg.timestamp != null &&
                msg.timestamp! > DateTime.now().subtract(const Duration(seconds: 60)).millisecondsSinceEpoch) {
              handleEvent(msg);
            }
          }
        },
        error: (error, stack) {
          handleError(error, stack);
        },
        loading: () {},
      );
    },
  );
}
```

### 11. Message Stream Provider

The message stream is provided by `mostroMessageStreamProvider`:

```dart
// lib/shared/providers/mostro_storage_provider.dart:11-15
final mostroMessageStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestMessage(orderId);
});
```

#### Purpose and Functionality

The `mostroMessageStreamProvider` serves several critical purposes in the order management system:

1. **Real-time Message Monitoring**: 
   - Continuously watches for new messages related to a specific order
   - Provides reactive updates when new messages arrive
   - Enables immediate UI updates without polling

2. **State Synchronization**:
   - Ensures all components observing an order receive the same message updates
   - Maintains consistency across different parts of the application
   - Prevents race conditions in state updates

3. **Memory Efficiency**:
   - Uses Riverpod's family provider pattern to create separate streams per order
   - Automatically manages stream lifecycle based on order ID
   - Prevents memory leaks by cleaning up unused streams

4. **Decoupled Architecture**:
   - Separates message storage from message consumption
   - Allows multiple components to subscribe to the same message stream
   - Enables easy testing and mocking of message flows

5. **Error Handling**:
   - Provides error states for failed message retrievals
   - Enables graceful degradation when storage operations fail
   - Maintains application stability during network issues

#### Stream Behavior

The provider returns the latest message for a given order ID:
- **Initial State**: Returns `null` if no messages exist for the order
- **Message Updates**: Emits new values when messages are added to storage
- **Ordering**: Messages are sorted by timestamp (newest first)
- **Deduplication**: Prevents duplicate message emissions

#### Usage Pattern

Components typically consume the stream like this:

```dart
// Example usage in a widget
class OrderWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messageStream = ref.watch(mostroMessageStreamProvider(orderId));
    
    return messageStream.when(
      data: (message) => _buildOrderUI(message),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => ErrorWidget(error),
    );
  }
}
```

### 10. State Update Processing

When a `new-order` confirmation message arrives, the state is updated:

```dart
// lib/features/order/models/order_state.dart lines 95-140
OrderState updateWith(MostroMessage message) {
  _logger.i('Updating OrderState with Action: ${message.action}');

  // Determine the new status based on the action received
  Status newStatus = _getStatusFromAction(message.action, message.getPayload<Order>()?.status);

  final newState = copyWith(
    status: newStatus,
    action: message.action,
    order: message.payload is Order ? message.getPayload<Order>() : order,
    // ... other fields
  );

  return newState;
}
```

### 11. Action Handling

The `new-order` action is handled in the `AbstractMostroNotifier`:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart lines 75-77
switch (event.action) {
  case Action.newOrder:
    break; // No special handling needed, state is already updated
  // ... other cases
}
```

### 12. Status Mapping

The status for `new-order` actions is mapped in `OrderState`:

```dart
// lib/features/order/models/order_state.dart lines 245-247
case Action.newOrder:
  return payloadStatus ?? status; // Usually 'pending'
```

## Confirmation Message Structure

The confirmation message from Mostro contains:

```json
{
  "order": {
    "version": 1,
    "id": "<Order id>",
    "action": "new-order",
    "payload": {
      "order": {
        "id": "<Order id>",
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "USD",
        "fiat_amount": 100,
        "payment_method": "Lightning",
        "premium": 1,
        "created_at": 1698870173
      }
    }
  }
}
```

## Public Order Publication

Mostro also publishes the order as a public NIP-69 event (kind 38383) that other users can discover. **Important Privacy Note**: NIP-69 events only contain 4 basic statuses to maintain user privacy and prevent order-to-user correlation. The real detailed order statuses are only sent via encrypted DM messages to the app.

### NIP-69 Event Structure (Public)

```json
{
  "id": "<Event id>",
  "pubkey": "<Mostro's pubkey>",
  "created_at": 1702548701,
  "kind": 38383,
  "tags": [
    ["d", "<Order id>"],
    ["k", "sell"],
    ["f", "USD"],
    ["s", "pending"], // Only 4 basic statuses: pending, canceled, in-progress, success
    ["amt", "0"],
    ["fa", "100"],
    ["pm", "Lightning"],
    ["premium", "1"],
    ["expiration", "1719391096"]
  ],
  "content": "",
  "sig": "<Mostro's signature>"
}
```

### Privacy Design

The NIP-69 protocol limits order statuses to only 4 basic states:
- **pending**: Order is available for taking
- **canceled**: Order was canceled
- **in-progress**: Order is in progress
- **success**: Order finished successfully  

This design prevents:
- **Order correlation**: Users cannot link orders to specific users
- **Privacy leaks**: Detailed order states remain private
- **Timing attacks**: Real order progression is hidden from public view

The detailed order states (waitingPayment, waitingBuyerInvoice, fiatSent, etc.) are only communicated via encrypted DM messages between Mostro and the order participants.

## Error Handling

The order creation process includes comprehensive error handling:

1. **Network Errors**: Handled in `MostroService._onData()`
2. **Decryption Errors**: Caught and logged
3. **Storage Errors**: Handled in `MostroStorage.addMessage()`
4. **State Update Errors**: Handled in `OrderState.updateWith()`

## Session Management

Orders are associated with sessions that contain:
- **Master Key**: User's identity key
- **Trade Key**: Ephemeral key for this specific trade
- **Key Index**: Index for key derivation
- **Order ID**: Unique identifier for the order

Sessions are managed by `SessionNotifier` and persist throughout the order lifecycle.

## UI Updates and Order Display

When the confirmation message is received, the order appears in multiple UI locations with different contexts:

### 1. Order State Update
- The order state is updated to `pending`
- The UI reflects that the order was created successfully

### 2. My Trades Tab
The order appears in the "My Trades" tab, which shows all orders where the user is a participant (either as maker or taker). This includes:
- Orders created by the user (maker)
- Orders taken by the user (taker)
- Orders in various states (pending, active, fiat-sent, etc.)

### 3. Orders Tab with User Distinction
The order also appears in the "Orders" tab (public order book) with a special distinction that indicates the user is the creator:

#### Visual Indicators
- **"You are selling"** - For sell orders created by the user
- **"You are buying"** - For buy orders created by the user

#### Implementation Details
The UI distinguishes user-created orders by:
1. **Order Ownership Check**: The app compares the order's creator pubkey with the user's master key
2. **Visual Labeling**: Orders created by the user show ownership indicators
3. **Different Actions**: User-created orders may have different action buttons (e.g., "Cancel" instead of "Take")

#### Code Implementation
The ownership check is typically implemented in the order display widgets:

```dart
// Example logic for determining order ownership
bool isUserOrder = order.masterBuyerPubkey == userMasterKey.public || 
                   order.masterSellerPubkey == userMasterKey.public;

// UI conditional rendering
if (isUserOrder) {
  Text(order.kind == OrderType.sell ? "You are selling" : "You are buying");
} else {
  // Show normal order display for other users' orders
}
```

### 4. Public Order Book Visibility
The order becomes visible to other users in the public order book (Orders tab) without the ownership indicators, showing only the basic order information.

### 5. Order Management
User-created orders provide additional management options:
- **Cancel Order**: Users can cancel their own pending orders
- **Order Details**: Access to detailed order information
- **Trade History**: Track the order through its lifecycle

## Key Dependencies

- **Riverpod**: State management and dependency injection
- **Sembast**: Local database storage
- **dart_nostr**: Nostr protocol implementation
- **Logger**: Logging and debugging

## Complete Order Creation Flow Summary

The order creation process follows a sophisticated multi-step flow that ensures reliability, security, and real-time updates:

### **Phase 1: Order Submission**
1. **User Input**: User creates order through UI (`add_order_screen.dart`)
2. **Message Creation**: `AddOrderNotifier` creates `MostroMessage` with `Action.newOrder`
3. **Session Creation**: New session created with fresh trade key
4. **Message Submission**: Message sent to `MostroService`

### **Phase 2: Message Processing**
5. **Session Retrieval**: `MostroService` retrieves session by `requestId`
6. **Message Wrapping**: NIP-59 gift wrap encryption with trade key
7. **Event Publishing**: Encrypted event sent to Mostro via Nostr relays

### **Phase 3: Mostro Processing**
8. **Message Reception**: Mostro receives and decrypts the message
9. **Order Validation**: Mostro validates order parameters
10. **Order ID Generation**: Mostro assigns unique order ID
11. **Public Publication**: Order published as NIP-69 event (kind 38383)
12. **Confirmation Response**: Mostro sends confirmation back to user's trade key

### **Phase 4: Confirmation Handling**
13. **Message Reception**: App receives encrypted confirmation via `MostroService._onData()`
14. **Session Matching**: App finds matching session using trade key
15. **Message Decryption**: NIP-59 gift wrap unwrapped using trade key
16. **Message Storage**: Confirmation stored in `MostroStorage`
17. **Confirmation Processing**: `AddOrderNotifier._confirmOrder()` handles confirmation
18. **Session Linking**: Session linked to confirmed order ID
19. **Order Notifier Creation**: New `OrderNotifier` created for ongoing management
20. **Navigation**: User navigated to order confirmation screen

### **Key Technical Details**

#### **Message Flow**:
```
User → AddOrderNotifier → MostroService → Nostr Relays → Mostro
                                                              ↓
User ← AddOrderNotifier ← MostroService ← Nostr Relays ← Mostro (confirmation)
```

#### **Key Components**:
- **`AddOrderNotifier`**: Handles order creation and confirmation
- **`MostroService`**: Manages message encryption/decryption and Nostr communication
- **`SessionNotifier`**: Manages trading sessions and key derivation
- **`OrderNotifier`**: Handles ongoing order management after confirmation
- **`MostroStorage`**: Local storage for encrypted messages

#### **Security Features**:
- **NIP-59 Gift Wrap**: Triple-layer encryption (rumor, seal, wrapper)
- **Trade Key Rotation**: Each order uses a unique trade key
- **Session Management**: Secure session linking and persistence
- **Message Deduplication**: Prevents duplicate message processing

#### **State Management**:
- **Riverpod Providers**: Reactive state management throughout the flow
- **Stream-based Updates**: Real-time message processing and UI updates
- **Error Handling**: Comprehensive error handling and recovery
- **Navigation Integration**: Seamless UI transitions based on order state

### **Critical Success Factors**

1. **Reliability**: Messages are encrypted, stored locally, and processed reliably
2. **Consistency**: State is managed centrally through Riverpod providers
3. **Real-time Updates**: Stream-based architecture for immediate UI updates
4. **Error Recovery**: Comprehensive error handling and logging throughout
5. **Protocol Compliance**: Follows the Mostro protocol specification exactly
6. **Security**: End-to-end encryption with proper key management
7. **User Experience**: Seamless flow from order creation to confirmation

This architecture provides a robust foundation for order management while maintaining security, reliability, and excellent user experience. The clear separation of concerns between order creation (`AddOrderNotifier`) and ongoing management (`OrderNotifier`) ensures maintainable and scalable code.
