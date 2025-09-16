# Request ID Analysis and Usage

## Overview

The `requestId` is a **temporary unique identifier** used to track and manage sessions during the order creation process before the order is confirmed and assigned a permanent `orderId`.

### Key Characteristics
- **Type**: `int` (32-bit integer)
- **Generation**: Based on order UUID + current timestamp
- **Purpose**: Temporary identifier for sessions during order creation
- **Lifetime**: From order creation until confirmation by Mostro

## Files Using `requestId`

### Primary Files

#### A. `lib/features/order/notfiers/add_order_notifier.dart`
```dart
class AddOrderNotifier extends AbstractMostroNotifier {
  late int requestId;  // Line 13
  
  AddOrderNotifier(super.orderId, super.ref) {
    requestId = _requestIdFromOrderId(orderId);  // Line 17
  }
  
  int _requestIdFromOrderId(String orderId) {  // Lines 21-26
    final uuid = orderId.replaceAll('-', '');
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return (int.parse(uuid.substring(0, 8), radix: 16) ^ timestamp) & 0x7FFFFFFF;
  }
}
```

#### B. `lib/shared/notifiers/session_notifier.dart`
```dart
class SessionNotifier extends StateNotifier<List<Session>> {
  final Map<int, Session> _requestIdToSession = {};  // Line 19
  
  Future<Session> newSession({String? orderId, int? requestId, Role? role}) async {  // Line 73
    // ... session creation ...
    if (requestId != null) {
      _requestIdToSession[requestId] = session;  // Line 96
    }
  }
  
  Session? getSessionByRequestId(int requestId) {  // Lines 118-124
    return _requestIdToSession[requestId];
  }
  
  void cleanupRequestSession(int requestId) {  // Lines 165-171
    final session = _requestIdToSession.remove(requestId);
    // ... cleanup ...
  }
}
```

#### C. `lib/services/mostro_service.dart`
```dart
Future<Session> _getSession(MostroMessage order) async {  // Lines 220-236
  if (order.requestId != null) {
    final session = sessionNotifier.getSessionByRequestId(order.requestId!);
    if (session == null) {
      throw Exception('No session found for requestId: ${order.requestId}');
    }
    return session;
  }
  // ... fallback to orderId ...
}
```

#### D. `lib/data/models/mostro_message.dart`
```dart
class MostroMessage<T extends Payload> {
  int? requestId;  // Line 17
  
  MostroMessage({
    this.requestId,  // Line 25
    // ... other fields ...
  });
  
  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,  // Line 87
      // ... other fields ...
    };
  }
  
  factory MostroMessage.fromJson(Map<String, dynamic> json) {
    final num requestId = json['request_id'] ?? 0;  // Line 101
    return MostroMessage(
      requestId: requestId.toInt(),  // Line 105
      // ... other fields ...
    );
  }
}
```

## Usage Situations

### Situation 1: New Order Creation

#### Complete Flow:
```dart
// 1. User initiates order creation
AddOrderNotifier.submitOrder(Order order) {
  // 2. Generate unique requestId
  requestId = _requestIdFromOrderId(orderId);
  
  // 3. Create message with requestId
  final message = MostroMessage<Order>(
    action: Action.newOrder,
    requestId: requestId,  // ← Used here
    payload: order,
  );
  
  // 4. Create temporary session with requestId
  session = await sessionNotifier.newSession(
    requestId: requestId,  // ← Used here
    role: Role.buyer,
  );
  
  // 5. Send message to Mostro
  await mostroService.submitOrder(message);
}
```

#### Why is it used here?
- **Temporary identification**: The order doesn't have an `orderId` yet (assigned after confirmation)
- **Session tracking**: We need to link the cryptographic session with the request
- **Message routing**: Mostro needs to know which session to respond to

### Situation 2: Message Processing

#### Processing Flow:
```dart
// In MostroService._getSession()
Future<Session> _getSession(MostroMessage order) async {
  if (order.requestId != null) {
    // Find session by requestId (for orders in progress)
    final session = sessionNotifier.getSessionByRequestId(order.requestId!);
    return session;
  } else if (order.id != null) {
    // Find session by orderId (for confirmed orders)
    final session = sessionNotifier.getSessionByOrderId(order.id!);
    return session;
  }
}
```

#### Why is it used here?
- **Message routing**: Determine which session to use for encryption/decryption
- **State management**: Maintain cryptographic context during communication
- **Fallback**: If no `orderId`, use `requestId` as identifier

### Situation 3: Order Confirmation

#### Confirmation Flow:
```dart
// In AddOrderNotifier._confirmOrder()
void _confirmOrder(MostroMessage message) {
  // 1. Link temporary session with permanent orderId
  session.orderId = message.id;  // Now we have orderId
  
  // 2. Save session with orderId
  sessionNotifier.saveSession(session);
  
  // 3. Session can now be found by orderId
  // requestId is no longer needed for this order
}
```

#### Why is it used here?
- **State transition**: From temporary (`requestId`) to permanent (`orderId`)
- **Persistence**: Save session for future use
- **Cleanup**: `requestId` can be cleaned up after confirmation

### Situation 4: Error Handling and Retries

#### Error Flow:
```dart
// In AbstractMostroNotifier
if (cantDo?.cantDoReason == CantDoReason.outOfRangeSatsAmount) {
  if (event.requestId != null) {
    // Clean temporary session to allow retry
    ref.read(sessionNotifierProvider.notifier).cleanupRequestSession(event.requestId!);
  }
}

// In AddOrderNotifier._retryAfterError()
void _retryAfterError() {
  // Generate new requestId for retry
  requestId = _requestIdFromOrderId(orderId);
  
  // Re-subscribe with new requestId
  subscription?.close();
  subscribe();
}
```

#### Why is it used here?
- **State cleanup**: Remove failed sessions
- **Retries**: Allow new attempts with new `requestId`
- **Isolation**: Each attempt has its own cryptographic context

## Request ID Generation

### Generation Algorithm:
```dart
int _requestIdFromOrderId(String orderId) {
  // 1. Remove dashes from UUID
  final uuid = orderId.replaceAll('-', '');
  
  // 2. Get current timestamp
  final timestamp = DateTime.now().microsecondsSinceEpoch;
  
  // 3. Combine UUID and timestamp
  return (int.parse(uuid.substring(0, 8), radix: 16) ^ timestamp) & 0x7FFFFFFF;
}
```

### Algorithm Characteristics:
- **Deterministic**: Same `orderId` + same time = same `requestId`
- **Unique**: XOR with timestamp ensures temporal uniqueness
- **Range**: `& 0x7FFFFFFF` ensures positive 32-bit value
- **Reproducible**: Useful for debugging and testing

## Request ID Lifecycle

### Lifecycle Phases:

#### Phase 1: Generation
```
User creates order → AddOrderNotifier → Generates requestId → Creates temporary session
```

#### Phase 2: Active Use
```
Message sent → Mostro processes → Response received → Session used for encryption
```

#### Phase 3: Transition
```
Mostro confirms → Assigns orderId → Session linked to orderId → requestId obsolete
```

#### Phase 4: Cleanup
```
Session saved → requestId cleaned → Memory freed
```

## System Advantages

### Technical Advantages:
1. **Unique identification**: Each request has its own identifier
2. **Session management**: Allows multiple simultaneous orders
3. **Error handling**: Facilitates cleanup and retries
4. **Debugging**: Complete request traceability
5. **Isolation**: Each order has independent cryptographic context

### Security Advantages:
1. **Unique keys**: Each order uses its own trade key
2. **Cryptographic isolation**: No interference between orders
3. **Automatic cleanup**: Temporary sessions are automatically removed
4. **Key rotation**: Each order increments the key index

## Specific Use Cases

### Case 1: Multiple Simultaneous Orders
```dart
// User creates 3 orders simultaneously
Order A → requestId: 1234567890 → Session A
Order B → requestId: 2345678901 → Session B  
Order C → requestId: 3456789012 → Session C

// Each order maintains its own cryptographic context
```

### Case 2: Retry After Error
```dart
// First attempt fails
requestId: 1234567890 → Error → Cleanup

// Second attempt
requestId: 1234567891 → New session → Success
```

### Case 3: Order Confirmation
```dart
// Before confirmation
requestId: 1234567890 → Temporary session

// After confirmation  
orderId: "abc-123-def" → Permanent session
requestId: 1234567890 → Cleaned
```

## Integration with Mostro Protocol

### In the Protocol:
```json
{
  "version": 1,
  "request_id": 1234567890,
  "action": "new-order",
  "trade_index": 5,
  "payload": { ... }
}
```

### Purpose in Protocol:
- **Identification**: Mostro knows which request to respond to
- **Tracking**: Request state tracking
- **Matching**: Link responses with requests
- **Debugging**: Logs and traceability in Mostro

## Session Management Architecture

### Session Storage Structure:
```dart
class SessionNotifier {
  // Permanent sessions (confirmed orders)
  final Map<String, Session> _sessions = {};
  
  // Temporary sessions (orders in progress)
  final Map<int, Session> _requestIdToSession = {};
}
```

### Session Lookup Priority:
1. **By requestId**: For orders in progress
2. **By orderId**: For confirmed orders
3. **Fallback**: Error if neither found

## Error Handling and Recovery

### Error Scenarios:
1. **Session not found**: `Exception('No session found for requestId: ${order.requestId}')`
2. **Order creation failure**: Cleanup temporary session
3. **Retry mechanism**: Generate new requestId for new attempt

### Recovery Mechanisms:
1. **Automatic cleanup**: Remove failed sessions
2. **Retry with new ID**: Generate fresh requestId
3. **State reset**: Return to initial clean state

## Performance Considerations

### Memory Management:
- **Temporary storage**: `_requestIdToSession` map for active requests
- **Automatic cleanup**: Sessions removed after confirmation or error
- **Bounded growth**: Limited by active order creation attempts

### Lookup Performance:
- **O(1) lookup**: Hash map access for session retrieval
- **Minimal overhead**: Simple integer-based key
- **Efficient cleanup**: Direct map removal

## Security Implications

### Cryptographic Isolation:
- **Unique trade keys**: Each requestId gets its own trade key
- **Session separation**: No cross-contamination between orders
- **Key rotation**: Automatic key index increment

### Privacy Protection:
- **Temporary identifiers**: requestId not persisted long-term
- **Session cleanup**: Automatic removal of temporary data
- **Isolated contexts**: Each order maintains separate cryptographic state

## Testing and Debugging

### Debugging Features:
- **Request traceability**: Complete flow tracking
- **Session logging**: Detailed session creation/cleanup logs
- **Error context**: Clear error messages with requestId

### Test Scenarios:
1. **Multiple orders**: Verify isolation between concurrent orders
2. **Error recovery**: Test retry mechanisms
3. **Session cleanup**: Verify proper memory management
4. **Protocol integration**: Test Mostro communication

## Future Considerations

### Potential Improvements:
1. **Request ID persistence**: For advanced debugging
2. **Session analytics**: Track session lifecycle metrics
3. **Enhanced error recovery**: More sophisticated retry strategies
4. **Performance monitoring**: Track session lookup performance

### Scalability:
- **Concurrent orders**: System handles multiple simultaneous orders
- **Memory efficiency**: Automatic cleanup prevents memory leaks
- **Lookup performance**: O(1) session retrieval

## Conclusion

The `requestId` is a **critical component** of the session management system that:

1. **Temporarily identifies** orders during their creation
2. **Manages cryptographic sessions** before confirmation
3. **Facilitates message routing** between app and Mostro
4. **Enables error handling** and retries
5. **Ensures isolation** between multiple simultaneous orders
6. **Simplifies state transition** from temporary to permanent

It is essential for the correct functioning of the Mostro protocol and the secure management of cryptographic sessions in the application.

## Related Documentation

- [Order Creation Process](ORDER_CREATION_PROCESS.md)
- [Session and Key Management](SESSION_AND_KEY_MANAGEMENT.md)
- [Mostro Protocol Overview](../protocol/overview.md)
