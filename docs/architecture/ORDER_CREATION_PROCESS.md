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

## Order Creation Flow

### 1. User Initiates Order Creation

The user creates an order through the UI (sell or buy order). This typically happens in order creation screens that collect:
- Order type (sell/buy)
- Fiat amount
- Payment methods
- Premium percentage
- Other order parameters

### 2. Order Message Construction

The app constructs a `MostroMessage` with the order details:

```dart
// Example from lib/services/mostro_service.dart
Future<void> submitOrder(MostroMessage order) async {
  await publishOrder(order);
}
```

The message follows the Mostro protocol specification (see [Mostro Protocol Documentation](https://mostro.network/protocol/new_sell_order.html)):

```json
{
  "order": {
    "version": 1,
    "action": "new-order",
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

### 3. Message Encryption and Publishing

The order message is processed through the `publishOrder` method in `MostroService`:

```dart
// lib/services/mostro_service.dart lines 200-220
Future<void> publishOrder(MostroMessage order) async {
  final session = await _getSession(order);

  final event = await order.wrap(
    tradeKey: session.tradeKey,
    recipientPubKey: _settings.mostroPublicKey,
    masterKey: session.fullPrivacy ? null : session.masterKey,
    keyIndex: session.fullPrivacy ? null : session.keyIndex,
  );
  
  _logger.i('Sending DM, Event ID: ${event.id} with payload: ${order.toJson()}');
  await ref.read(nostrServiceProvider).publishEvent(event);
}
```

Key steps:
1. **Session Retrieval**: Gets the current session for the order
2. **Message Wrapping**: Encrypts the message using NIP-59 (Gift wrap) with the trade key
3. **Event Publishing**: Sends the encrypted event to Mostro via Nostr relays

### 4. Mostro Network Processing

Mostro receives the encrypted order message and:
1. Decrypts the message using the trade key
2. Validates the order parameters
3. Generates a unique order ID
4. Publishes the order as a public NIP-69 event (kind 38383)
5. Sends a confirmation message back to the user

### 5. Confirmation Message Reception

The app continuously monitors for incoming messages through the `MostroService`:

```dart
// lib/services/mostro_service.dart lines 40-80
void init() {
  _ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
    _onData,
    onError: (error, stackTrace) {
      _logger.e('Error in orders subscription', error: error, stackTrace: stackTrace);
    },
    cancelOnError: false,
  );
}

Future<void> _onData(NostrEvent event) async {
  // ... event validation and storage ...
  
  final decryptedEvent = await event.unWrap(privateKey);
  final result = jsonDecode(decryptedEvent.content!);
  final msg = MostroMessage.fromJson(result[0]);
  
  final messageStorage = ref.read(mostroStorageProvider);
  await messageStorage.addMessage(decryptedEvent.id!, msg);
}
```

### 6. Message Storage

The confirmation message is stored locally using `MostroStorage`:

```dart
// lib/data/repositories/mostro_storage.dart lines 13-30
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

### 7. Order State Management

The `OrderNotifier` manages the order state and subscribes to message updates:

```dart
// lib/features/order/notfiers/order_notifier.dart lines 15-25
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

### 8. Message Stream Subscription

The notifier subscribes to message streams using Riverpod providers:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart lines 35-55
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

### 9. Message Stream Provider

The message stream is provided by `mostroMessageStreamProvider`:

```dart
// lib/shared/providers/mostro_storage_provider.dart lines 11-15
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

## Summary

The order creation process is a multi-step flow that ensures:
1. **Reliability**: Messages are encrypted and stored locally
2. **Consistency**: State is managed centrally through Riverpod
3. **Real-time Updates**: Stream-based architecture for immediate UI updates
4. **Error Recovery**: Comprehensive error handling and logging
5. **Protocol Compliance**: Follows the Mostro protocol specification

This architecture provides a robust foundation for order management while maintaining security and user experience.
