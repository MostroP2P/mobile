# Relay Timestamp Bug Analysis: False Timeout Detection

## Overview

This document analyzes a critical bug where valid orders in `waiting-seller-to-pay` status are incorrectly detected as "timed out" and cleaned up, causing active trades to disappear from "My Trades". The root cause is a race condition between public events (kind 38383) from multiple relays with different propagation delays.

## Bug Description

### Symptoms
- Orders in `waiting-seller-to-pay` status suddenly disappear from "My Trades"
- Users see "Real-time timeout detected" log message
- Active trading sessions are incorrectly terminated
- False timeout notifications sent to users

### Affected Order States
- `waiting-buyer-invoice` → `waiting-payment` (Status enum)
- `waiting-seller-to-pay` → `waiting-payment` (Status enum)

## Root Cause Analysis

### The Problem: Relay Event Propagation Race Condition

The application subscribes to public events (kind 38383) from **all configured relays simultaneously**. Different relays can have different propagation delays, causing the same event to arrive at different times with potentially different states.

### Critical Code Paths

#### 1. Public Event Collection (`OpenOrdersRepository`)
```dart
// lib/data/repositories/open_orders_repository.dart:51-53
_subscription = _nostrService.subscribeToEvents(request).listen((event) {
  if (event.type == 'order') {
    _events[event.orderId!] = event; // ← OVERWRITES without timestamp check
    _eventStreamController.add(_events.values.toList());
  }
```

#### 2. Event Provider Selection (`order_repository_provider.dart`)
```dart
// lib/shared/providers/order_repository_provider.dart:34-35
return allEvents
    .lastWhereOrNull((evt) => (evt as NostrEvent).orderId == orderId);
    // ← LAST event wins, not NEWEST by timestamp
```

#### 3. Timeout Detection Logic (`OrderNotifier`)
```dart
// lib/features/order/notfiers/order_notifier.dart:226-229
// SECOND: Check for timeout - simplified logic without timestamps
if (publicEvent.status == Status.pending &&
    (currentState.status == Status.waitingBuyerInvoice ||
        currentState.status == Status.waitingPayment)) {
  // ← NO timestamp comparison between public event and gift-wrap
```

### Race Condition Scenario

#### Normal Flow (No Bug)
1. **Private Message**: `waiting-seller-to-pay` → Local state: `waiting-payment`
2. **Public Event**: `waiting-payment` → All relays synchronized
3. **Timeout Check**: `public=waiting-payment + local=waiting-payment` → ✅ No timeout

#### Buggy Flow (Race Condition)
1. **Private Message**: `waiting-seller-to-pay` → Local state: `waiting-payment`
2. **Relay A (Fast)**: Receives public event `status: "waiting-payment"`
3. **Relay B (Slow)**: Still has public event `status: "pending"`
4. **App receives from Relay A**: Public state = `waiting-payment` ✅
5. **App receives from Relay B**: Public state = `pending` ← **OVERWRITES** newer event
6. **Timeout Check**: `public=pending + local=waiting-payment` → ❌ **FALSE TIMEOUT**

## Evidence from Logs (logs4.txt)

### Log Sequence Analysis
```
Line 773: Received message: {..., "action": "add-invoice", "status": "waiting-buyer-invoice"}
Line 893: Received message: {..., "action": "waiting-seller-to-pay", "payload": null}
Line 1555: Order taken by user - cleaning up session as order will be removed from My Trades
Line 1573: Real-time timeout detected - cleaning up session for order 8ebe5f6a-00ed-4a3e-b561-f24e28c7e6bf
```

### Key Observations
1. **Valid State Progression**: Order correctly moves from `add-invoice` to `waiting-seller-to-pay`
2. **Incorrect Classification**: System thinks "order taken by user" (taker scenario)
3. **False Timeout**: Despite being in valid `waiting-payment` state
4. **Session Cleanup**: Active trading session incorrectly terminated

## Technical Details

### Action to Status Mapping
```dart
// lib/features/order/models/order_state.dart:195-197
case Action.waitingSellerToPay:
case Action.payInvoice:
  return Status.waitingPayment; // ← Correct mapping
```

### Missing Timestamp Validation
The current timeout detection explicitly avoids timestamp comparison:
```dart
// Line 226: "simplified logic without timestamps"
if (publicEvent.status == Status.pending && ...) {
  // Should compare: publicEvent.createdAt vs latestGiftWrap.timestamp
}
```

### Relay Event Overwriting Problem
```dart
// OpenOrdersRepository - No timestamp-based deduplication
_events[event.orderId!] = event; // ← Simple overwrite by orderId
```

## Impact Assessment

### User Experience Impact
- **High**: Active trades suddenly disappear
- **Confusing**: Users think their orders were canceled
- **Financial Risk**: Users may lose trading opportunities
- **Trust Issues**: App appears unreliable

### Technical Impact
- **Data Loss**: Trading session state lost
- **Inconsistent UI**: Orders vanish from "My Trades"
- **False Notifications**: Incorrect timeout messages
- **Navigation Issues**: Users redirected to order book unexpectedly

## Contributing Factors

### 1. Multi-Relay Architecture
- App connects to multiple relays simultaneously
- No relay prioritization or consensus mechanism
- Events can arrive in any order from different sources

### 2. Last-Event-Wins Strategy
- `lastWhereOrNull` picks chronologically last received event
- No consideration of event creation timestamp
- Slower relays can overwrite faster relays

### 3. No Timestamp Validation
- Timeout detection explicitly avoids timestamp comparison
- Cannot distinguish between legitimate timeout and propagation delay
- Creates false positives during normal relay synchronization

### 4. Immediate Timeout Trigger
- No grace period for relay synchronization
- Timeout detection happens on every public event change
- No debouncing or multiple confirmation requirement

## Similar Issues in Codebase

### Related Timeout Systems
1. **10-second cleanup timers**: These work correctly with proper cancellation
2. **Gift-wrap timestamp validation**: 60-second threshold works properly
3. **This public event timeout**: No timestamp validation - broken

### Inconsistent Approach
The codebase has other timestamp-based validations but this critical timeout detection omits them:
```dart
// AbstractMostroNotifier.dart:62-66 - GOOD timestamp validation
if (msg.timestamp != null &&
    msg.timestamp! > DateTime.now().subtract(const Duration(seconds: 60)).millisecondsSinceEpoch) {
  unawaited(handleEvent(msg));
}

// OrderNotifier.dart:226 - BAD: no timestamp validation
// "simplified logic without timestamps"
```

## Proposed Solutions (Analysis Only)

### Solution 1: Timestamp-Based Event Selection
Instead of last-received-wins, use newest-by-timestamp-wins:
```dart
// Compare: publicEvent.createdAt vs latestGiftWrap.timestamp
if (publicEvent.createdAt > latestGiftWrap.timestamp) {
  // Public event is newer - potential timeout
} else {
  // Public event is older - ignore for timeout detection
}
```

### Solution 2: Relay Consensus Mechanism
Require multiple relays to report same status before triggering timeout:
- Wait for confirmation from majority of relays
- Add relay consensus threshold configuration
- Implement timeout only after relay agreement

### Solution 3: Grace Period Implementation
Add time-based buffer for relay synchronization:
- 30-60 second grace period after status change
- Only check timeout after sufficient time for propagation
- Prevent immediate false positives

### Solution 4: Event Deduplication by Timestamp
Improve event storage to prefer newer events:
```dart
// Only update if newer timestamp
if (newEvent.createdAt > existingEvent.createdAt) {
  _events[orderId] = newEvent;
}
```

## Risk Assessment

### High Risk Scenarios
1. **Network Partitions**: Some relays lag significantly behind others
2. **Relay Failures**: Failed relays send outdated cached events
3. **High Network Latency**: Geographical distribution causes delays
4. **Peak Usage**: Network congestion affects relay synchronization

### Low Risk Scenarios
1. **Single Relay Setup**: No race condition possible
2. **Identical Relay State**: All relays perfectly synchronized
3. **Offline Mode**: No public events received during trades

## Testing Recommendations

### Unit Tests Needed
1. **Multi-relay race condition simulation**
2. **Timestamp comparison logic validation**
3. **Event deduplication testing**
4. **Grace period timeout testing**

### Integration Tests Needed
1. **Simulated relay delays**
2. **Network partition scenarios**
3. **Relay failure recovery**
4. **End-to-end timeout scenarios**

### Manual Testing Scenarios
1. **Connect to slow/fast relay combinations**
2. **Monitor timeout behavior during network issues**
3. **Verify correct behavior with relay synchronization delays**

## Files Involved

### Core Files
- `lib/features/order/notfiers/order_notifier.dart` - Main timeout detection logic
- `lib/data/repositories/open_orders_repository.dart` - Public event collection
- `lib/shared/providers/order_repository_provider.dart` - Event provider selection
- `lib/services/nostr_service.dart` - Multi-relay connection management

### Related Files
- `lib/features/order/models/order_state.dart` - Status mapping
- `lib/features/order/notfiers/abstract_mostro_notifier.dart` - Timestamp validation patterns

## Monitoring and Detection

### Log Patterns to Watch
```
"Real-time timeout detected" - False positive indicator
"Order taken by user - cleaning up session" - Incorrect classification
"Timeout detected for order X: Public shows pending but local is Y" - Race condition
```

### Metrics to Track
- Timeout detection frequency by relay configuration
- Time delta between private and public event reception
- User complaints about disappearing orders
- Trading session termination rates

## Conclusion

This bug represents a fundamental flaw in the multi-relay event handling architecture. The combination of:

1. **No timestamp-based event ordering**
2. **Last-received-wins strategy**
3. **Immediate timeout detection**
4. **Multi-relay propagation delays**

Creates a perfect storm for false timeout detection. The bug primarily affects orders transitioning to `waiting-payment` status and causes legitimate active trades to be incorrectly terminated.

The solution requires implementing proper timestamp-based event validation and/or relay consensus mechanisms to distinguish between legitimate timeouts and propagation delays.

---

**Bug Severity**: High  
**Impact**: Active trading sessions incorrectly terminated  
**Frequency**: Occurs with multi-relay setups experiencing propagation delays  
**User Facing**: Yes - orders disappear from "My Trades"

**Last Updated**: December 26, 2024  
**Analysis Based On**: logs4.txt and codebase review  
**Status**: Bug confirmed, solution design needed