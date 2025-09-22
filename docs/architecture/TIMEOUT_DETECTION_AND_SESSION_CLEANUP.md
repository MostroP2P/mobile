# Session and Order Lifecycle Management - Mostro Mobile

## Overview

This document provides comprehensive technical documentation for Mostro Mobile's session and order lifecycle management system. The implementation handles timeout detection, order cancellation, session cleanup, and real-time countdown timers for trading operations.

**Purpose**: Technical reference for understanding the complete lifecycle management of trading sessions and orders.

**Scope**: Covers timeout detection system, session management patterns, countdown timer architecture, and the dual-channel approach for handling private sessions vs public order events.

---

## System Architecture

### Core Components

The lifecycle management system consists of five main components:

1. **OrderNotifier** - Real-time timeout detection and session cleanup
2. **SessionNotifier** - Session lifecycle management and storage
3. **Time Provider System** - Optimized countdown timers
4. **Event Provider Architecture** - Dual-channel Nostr event handling
5. **UI Integration** - Real-time countdown display and notifications

### Dual-Channel Architecture

The system uses two separate channels for different types of data:

#### **Private Channel (SubscriptionManager)**
- **Purpose**: Handles encrypted user sessions and private communications
- **Events**: Kind 1059 (encrypted gift-wrapped messages)
- **Usage**: "My Trades" data, private messaging, session state updates

#### **Public Channel (OrderNotifier + OpenOrdersRepository)**  
- **Purpose**: Handles public order discovery and timeout detection
- **Events**: Kind 38383 (public Mostro order events)
- **Usage**: Order Book display, timeout detection, cancellation monitoring

---

## Timeout Detection System

### Real-time Detection Architecture

The timeout detection system monitors orders in waiting states and automatically handles timeouts based on user role (maker vs taker).

#### **OrderNotifier Implementation**

```dart
// lib/features/order/notfiers/order_notifier.dart
class OrderNotifier extends AbstractMostroNotifier {
  bool _isSyncing = false;              // Sync operation protection
  bool _isProcessingTimeout = false;     // Timeout processing protection
  ProviderSubscription<AsyncValue<List<NostrEvent>>>? _publicEventsSubscription;
}
```

**Key Features**:
- **Race condition protection**: Separate flags for different operations
- **Real-time monitoring**: Subscribes to orderEventsProvider (38383 events)
- **Automatic cleanup**: Handles session deletion vs preservation based on user role

#### **Public Event Subscription**

```dart
// Lines 316-373: Real-time event monitoring
void _subscribeToPublicEvents() {
  _publicEventsSubscription = ref.listen(
    orderEventsProvider, // Stream of public 38383 events
    (_, next) async {
      if (_isProcessingTimeout) return; // Prevent concurrent processing
      
      try {
        _isProcessingTimeout = true;
        
        // Validate current state
        final currentSession = ref.read(sessionProvider(orderId));
        if (!mounted || currentSession == null) return;
        
        // Only monitor specific waiting states
        if (state.status != Status.pending &&
            state.status != Status.waitingBuyerInvoice && 
            state.status != Status.waitingPayment) return;
        
        // Process timeout/cancellation
        final shouldCleanup = await _checkTimeoutAndCleanup(state, latestGiftWrap);
        if (shouldCleanup) {
          ref.invalidateSelf(); // Invalidate provider to update UI
        }
      } finally {
        _isProcessingTimeout = false; // Always clean up flag
      }
    }
  );
}
```

### Timeout Detection Logic

The system uses simplified business logic instead of timestamp comparisons for reliability:

#### **Simplified Detection Algorithm**

```dart
// Lines 157-296: _checkTimeoutAndCleanup() implementation
Future<bool> _checkTimeoutAndCleanup(OrderState currentState, MostroMessage? latestGiftWrap) async {
  final publicEvent = ref.read(eventProvider(orderId));
  
  // PHASE 1: Cancellation Detection (independent of timestamps)
  if (publicEvent.status == Status.canceled) {
    if (currentState.status == Status.pending ||
        currentState.status == Status.waitingBuyerInvoice ||
        currentState.status == Status.waitingPayment) {
      // CANCELLED: Delete session for pending/waiting orders
      await sessionNotifier.deleteSession(orderId);
      return true; // Session cleaned up
    } else {
      // For active/completed orders: preserve session but update state
      state = state.copyWith(status: Status.canceled, action: Action.canceled);
      return false; // Session preserved
    }
  }
  
  // PHASE 2: Timeout Detection (simplified logic)
  if (publicEvent.status == Status.pending && 
      (currentState.status == Status.waitingBuyerInvoice || 
       currentState.status == Status.waitingPayment)) {
    // Timeout detected: Public=pending but local=waiting = guaranteed timeout
    
    final isCreatedByUser = _isCreatedByUser(currentSession, publicEvent);
    
    if (isCreatedByUser) {
      // MAKER SCENARIO: Preserve session, update state to pending
      
      // CRITICAL: Persist reversal to maintain pending state after app restart
      final timeoutMessage = MostroMessage.createTimeoutReversal(
        orderId: orderId,
        timestamp: publicTimestamp,
        originalStatus: currentState.status,
        publicEvent: publicEvent,
      );
      
      final messageKey = '${orderId}_timeout_$publicTimestamp';
      await storage.addMessage(messageKey, timeoutMessage);
      
      state = state.copyWith(status: Status.pending, action: Action.timeoutReversal);
      return false; // Session preserved
      
    } else {
      // TAKER SCENARIO: Delete session completely
      await sessionNotifier.deleteSession(orderId);
      return true; // Session cleaned up
    }
  }
  
  return false; // No timeout/cancellation detected
}
```

**Why This Approach Works**:
- **No timestamp dependency**: Eliminates clock synchronization issues
- **Status-based detection**: `public=pending + local=waiting = guaranteed timeout`
- **Independent cancellation**: Handles cancellations regardless of timing
- **State-based session rules**: Different behaviors based on local order state

### Maker vs Taker Differentiation

The system handles timeout scenarios differently based on whether the user created the order (maker) or took someone else's order (taker):

#### **Role Determination Logic**

```dart
// Lines 299-313: User role detection
bool _isCreatedByUser(Session session, NostrEvent publicEvent) {
  final userRole = session.role;
  final orderType = publicEvent.orderType;
  
  // User is creator if role matches order type
  if (userRole == Role.buyer && orderType == OrderType.buy) return true;
  if (userRole == Role.seller && orderType == OrderType.sell) return true;
  
  return false; // User took someone else's order (taker)
}
```

#### **Behavior by User Role**

**MAKER (Order Creator)**:
```
1. User creates order → Someone takes it → waiting state in My Trades
2. Taker doesn't respond → Mostro publishes 38383 with status=pending
3. System detects timeout automatically
4. Session preserved + state updated to pending
5. Notification: "Your counterpart didn't respond in time"
6. Order stays in My Trades as pending, ready for someone else to take
```

**TAKER (Order Accepter)**:
```
1. User takes order → Order appears in My Trades with waiting state
2. User doesn't respond in time → Mostro publishes 38383 with status=pending  
3. System detects timeout automatically
4. Session deleted + order disappears from My Trades
5. Notification: "You didn't respond in time"
6. Order returns to Order Book for others to take
```

---

## Session Management System

### SessionNotifier Core Implementation

The SessionNotifier manages the complete lifecycle of trading sessions:

```dart
// lib/shared/notifiers/session_notifier.dart
class SessionNotifier extends StateNotifier<List<Session>> {
  final Map<String, Session> _sessions = {};
  final Map<int, Session> _requestIdToSession = {}; // For temporary orders
  Timer? _cleanupTimer;

  Future<void> init() async {
    // Load all sessions and expire old ones
    final allSessions = await _storage.getAllSessions();
    final cutoff = DateTime.now()
        .subtract(const Duration(hours: Config.sessionExpirationHours));
    
    for (final session in allSessions) {
      if (session.startTime.isAfter(cutoff)) {
        _sessions[session.orderId!] = session;
      } else {
        await _storage.deleteSession(session.orderId!);
        _sessions.remove(session.orderId!);
      }
    }
    
    state = sessions; // Triggers all listeners
    _scheduleCleanup(); // Schedule periodic cleanup
  }

  Future<void> deleteSession(String sessionId) async {
    _sessions.remove(sessionId);
    await _storage.deleteSession(sessionId);
    state = sessions; // Update state to trigger UI updates
  }
}
```

**Key Features**:
- **Automatic expiration**: Removes sessions older than 36 hours (Config.sessionExpirationHours)
- **Periodic cleanup**: Scheduled cleanup every 30 minutes to prevent memory leaks
- **State synchronization**: Updates trigger automatic UI updates
- **Storage persistence**: Sessions survive app restarts

### Session Provider Pattern

The optimized session access pattern provides better performance and reactivity:

```dart
// lib/shared/providers/session_notifier_provider.dart
final sessionProvider = StateProvider.family<Session?, String>((ref, id) {
  final notifier = ref.watch(sessionNotifierProvider);
  return notifier.where((s) => s.orderId == id).firstOrNull;
});
```

**Benefits**:
- **Automatic reactivity**: UI updates when sessions change
- **Better performance**: Leverages Riverpod's optimization
- **Consistent pattern**: Used throughout the codebase
- **Future-proof**: Compatible with ongoing development

### Historical Context: SessionProvider Optimization Impact

#### **Before Optimization (Worked Implicitly)**
```dart
final sessionProvider = StateProvider.family<Session?, String>((ref, id) {
  final notifier = ref.watch(sessionNotifierProvider.notifier);
  return notifier.getSessionByOrderId(id); // Independent method
});
```

#### **After Optimization (Explicit Handling Required)**  
```dart
final sessionProvider = StateProvider.family<Session?, String>((ref, id) {
  final notifier = ref.watch(sessionNotifierProvider); // Directly tied to state
  return notifier.where((s) => s.orderId == id).firstOrNull; // Direct search
});
```

**Why The Change Required Explicit Timeout Handling**:

1. **`sessionProvider` became directly tied** to `sessionNotifierProvider` state
2. **"My Trades" depends on `sessionProvider`** to determine which orders to show
3. **Cancellations without explicit session deletion** meant sessions continued to exist
4. **Orphaned sessions** caused "My Trades" to show orders with stale status
5. **Solution required explicit session deletion** when timeouts/cancellations detected

---

## Countdown Timer System

### Optimized Time Provider Implementation

The countdown system uses an optimized Stream provider with debouncing and automatic cleanup:

```dart
// lib/shared/providers/time_provider.dart
final countdownTimeProvider = StreamProvider<DateTime>((ref) {
  late StreamController<DateTime> controller;
  Timer? timer;
  DateTime? lastEmittedTime;

  controller = StreamController<DateTime>.broadcast(
    onListen: () {
      // Start timer when first listener subscribes
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final now = DateTime.now();
        // Debounce: only emit if seconds have actually changed
        if (lastEmittedTime == null || 
            now.second != lastEmittedTime!.second ||
            now.minute != lastEmittedTime!.minute ||
            now.hour != lastEmittedTime!.hour) {
          lastEmittedTime = now;
          controller.add(now);
        }
      });
      // Emit initial value immediately
      controller.add(DateTime.now());
    },
    onCancel: () {
      // Cleanup when last listener unsubscribes
      timer?.cancel();
      timer = null;
      lastEmittedTime = null;
    },
  );

  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
```

**Optimizations**:
- **Debouncing**: Only emits when time values actually change
- **Automatic cleanup**: Cancels timer when no listeners
- **Resource efficiency**: Single timer supports multiple subscribers
- **Memory leak prevention**: Proper disposal handling

### Countdown UI Integration

#### **Real-time Countdown Widget**

```dart
// lib/features/trades/screens/trade_detail_screen.dart - Lines 862-1062
class _CountdownWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeAsync = ref.watch(countdownTimeProvider); // Updates every second
    final messagesAsync = ref.watch(mostroMessageHistoryProvider(orderId));
    
    return timeAsync.when(
      data: (currentTime) {
        return messagesAsync.maybeWhen(
          data: (messages) {
            final countdownWidget = _buildCountDownTime(
              context, ref, tradeState, messages, expiresAtTimestamp
            );
            return countdownWidget != null 
              ? Column(children: [countdownWidget, const SizedBox(height: 36)])
              : const SizedBox(height: 12);
          },
          orElse: () => const SizedBox(height: 12),
        );
      },
      loading: () => const SizedBox(height: 12),
      error: (error, stack) => const SizedBox(height: 12),
    );
  }
}
```

#### **State-Specific Countdown Logic**

The countdown displays different behaviors based on order status:

```dart
// Lines 916-1023: Countdown logic by order status
Widget? _buildCountDownTime(BuildContext context, WidgetRef ref, 
    OrderState tradeState, List<MostroMessage> messages, int? expiresAtTimestamp) {
  
  final status = tradeState.status;
  final now = DateTime.now();
  final mostroInstance = ref.read(orderRepositoryProvider).mostroInstance;
  
  if (status == Status.pending) {
    // PENDING ORDERS: Use expirationHours (default 24h)
    final expHours = mostroInstance?.expirationHours ?? 24;
    final expiration = expiresAtTimestamp != null
        ? DateTime.fromMillisecondsSinceEpoch(expiresAtTimestamp)
        : now.add(Duration(hours: expHours));
    
    final difference = expiration.isAfter(now) 
        ? expiration.difference(now) 
        : const Duration();
    
    final hoursLeft = difference.inHours.clamp(0, expHours);
    final minutesLeft = difference.inMinutes % 60;
    final secondsLeft = difference.inSeconds % 60;
    
    return CircularCountdown(
      countdownTotal: expHours,
      countdownRemaining: hoursLeft,
      text: '$hoursLeft:${minutesLeft.toString().padLeft(2, '0')}:${secondsLeft.toString().padLeft(2, '0')}',
    );
    
  } else if (status == Status.waitingBuyerInvoice || status == Status.waitingPayment) {
    // WAITING STATES: Use expirationSeconds (default 15 minutes)
    final stateMessage = _findMessageForState(messages, status);
    if (stateMessage == null || !isValidTimestamp(stateMessage.timestamp)) {
      return null;
    }
    
    final expSecs = mostroInstance?.expirationSeconds ?? 900;
    final messageTime = DateTime.fromMillisecondsSinceEpoch(stateMessage.timestamp!);
    final expiration = messageTime.add(Duration(seconds: expSecs));
    
    final difference = expiration.isAfter(now) 
        ? expiration.difference(now) 
        : const Duration();
    
    final expMinutes = (expSecs / 60).ceil();
    final minutesLeft = difference.inMinutes.clamp(0, expMinutes);
    final secondsLeft = difference.inSeconds % 60;
    
    return CircularCountdown(
      countdownTotal: expMinutes,
      countdownRemaining: minutesLeft,
      text: '$minutesLeft:${secondsLeft.toString().padLeft(2, '0')}',
    );
  } else {
    return null; // All other states: NO countdown displayed
  }
}
```

#### **Message State Detection**

```dart
// Lines 1025-1050: Find the message that caused the current state
MostroMessage? _findMessageForState(List<MostroMessage> messages, Status status) {
  // Sort messages by timestamp (most recent first)
  final sortedMessages = List<MostroMessage>.from(messages)
    ..sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));

  // Find message that caused the state
  for (final message in sortedMessages) {
    if (status == Status.waitingBuyerInvoice && 
        (message.action == Action.addInvoice || 
         message.action == Action.waitingBuyerInvoice)) {
      return message;
    } else if (status == Status.waitingPayment && 
        (message.action == Action.payInvoice || 
         message.action == Action.waitingSellerToPay)) {
      return message;
    }
  }
  return null;
}
```

**Countdown Display Rules**:
- **Status.pending**: Shows HH:MM:SS format with hours, uses Mostro instance `expirationHours`
- **Status.waitingBuyerInvoice**: Shows MM:SS format, uses `expirationSeconds` from state message timestamp  
- **Status.waitingPayment**: Shows MM:SS format, uses `expirationSeconds` from state message timestamp
- **All other statuses**: No countdown displayed (returns null)

---

## Event Provider Architecture

### Dual-Channel Event Handling

The system uses separate providers for different types of Nostr events:

#### **Public Event Providers**

```dart
// lib/shared/providers/order_repository_provider.dart
final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.read(orderRepositoryProvider);
  return orderRepository.eventsStream; // Stream of 38383 public events
});

final eventProvider = Provider.family<NostrEvent?, String>((ref, orderId) {
  final allEventsAsync = ref.watch(orderEventsProvider);
  final allEvents = allEventsAsync.maybeWhen(
    data: (data) => data,
    orElse: () => [],
  );
  return allEvents.lastWhereOrNull((evt) => evt.orderId == orderId);
});
```

#### **Private Event Handling**

The SubscriptionManager handles encrypted private events (Kind 1059) separately:

```dart
// Used by MostroService for processing private session messages
// Handles encrypted gift-wrapped messages for active trading sessions
// Separate from public event monitoring system
```

### Order Notifier Provider

```dart
// lib/features/order/providers/order_notifier_provider.dart
final orderNotifierProvider =
    StateNotifierProvider.family<OrderNotifier, OrderState, String>((ref, orderId) {
  return OrderNotifier(orderId, ref);
});
```

**Integration Points**:
- **OrderNotifier**: Handles timeout detection and session cleanup
- **OrderState**: Maintains current order state and action
- **Event Providers**: Supply real-time public event data for monitoring

---

## Data Flow and Integration

### Complete Detection Flow

```
1. Order in waiting state (waitingBuyerInvoice or waitingPayment)
2. OrderNotifier subscribes to orderEventsProvider (38383 events)
3. Mostro publishes new 38383 event: orderId + pending/canceled + newer timestamp
4. _subscribeToPublicEvents() detects change automatically via Riverpod listener
5. _checkTimeoutAndCleanup() processes the detected change
6. System determines maker vs taker role using _isCreatedByUser()
7. Applies appropriate action: update state (maker) or delete session (taker)
8. UI updates automatically through Riverpod reactive system
```

### State Management Flow

```dart
// Complete reactive chain
NostrEvent (38383) → orderEventsProvider → eventProvider → OrderNotifier listener
                                                          ↓
Session state ← sessionNotifier.deleteSession() ← timeout detection logic
     ↓
sessionProvider(orderId) → UI components → automatic updates
```

### Persistence and Recovery

**Session Persistence**: Sessions are stored in Sembast database and survive app restarts.

**Timeout State Persistence**: For maker scenarios, synthetic timeout messages are persisted:

```dart
final timeoutMessage = MostroMessage.createTimeoutReversal(
  orderId: orderId,
  timestamp: publicTimestamp,
  originalStatus: currentState.status,
  publicEvent: publicEvent,
);

final messageKey = '${orderId}_timeout_$publicTimestamp';
await storage.addMessage(messageKey, timeoutMessage);
```

This ensures that timeout-reverted orders maintain their pending state and show the cancel button after app restart.

---

## Synthetic Event Architecture (The "Fake Message Trick")

### What is a Synthetic Event?

A **synthetic event** is an **ARTIFICIAL/FAKE** `MostroMessage` created entirely by the mobile app that **never actually occurred** in the Nostr network. It is a local persistence technique used to simulate receiving a timeout reversal message that would otherwise not exist.

#### Key Characteristics of Synthetic Events

- **🚫 NOT REAL**: Never transmitted via Nostr protocol - exists only in local storage
- **🎭 ARTIFICIAL**: Completely fabricated by the mobile app, not by Mostro server
- **💾 LOCAL ONLY**: Stored in local Sembast database with unique keys
- **🎯 MAKER-SPECIFIC**: Only created for order creators (makers), never for takers
- **⏰ FAKE TIMESTAMP**: Uses the public event timestamp for consistency, but message itself is synthetic

### Why This "Trick" is Necessary

Without synthetic events, **maker orders would disappear** from "My Trades" after app restart:

#### The Problem Without Synthetic Events:
```
1. Maker creates order → appears in "My Trades"
2. Taker takes order → order moves to waiting state  
3. Timeout occurs → Mostro publishes public 38383 event (status=pending)
4. App detects timeout → updates local state to pending
5. 🚨 USER RESTARTS APP
6. ❌ App loads: NO persisted message indicating "pending due to timeout"  
7. ❌ Order disappears from "My Trades" (looks like it was never taken)
8. ❌ User confused: "Where did my order go?"
```

#### The Solution With Synthetic Events:
```
1-4. (Same as above)
5. 🎭 App creates FAKE timeout reversal message
6. 💾 Synthetic message stored: "order went pending due to timeout"
7. 🚨 USER RESTARTS APP  
8. ✅ App loads synthetic message: "Oh, this order timed out!"
9. ✅ Order stays in "My Trades" with correct pending status
10. ✅ User sees order with cancel button available
```

### How the "Fake Message" Works

#### 1. **Synthetic Message Creation**

The `MostroMessage.createTimeoutReversal()` factory creates a **completely artificial message**:

```dart
/// Creates an ARTIFICIAL message that simulates a timeout reversal
/// 
/// IMPORTANT: This message is FAKE - it never came from Nostr!
/// It's a local persistence trick to maintain UI state consistency.
factory MostroMessage.createTimeoutReversal({
  required String orderId,
  required int timestamp,        // ← Uses real public event timestamp
  required Status originalStatus, // ← The waiting state that timed out  
  required NostrEvent publicEvent, // ← Real 38383 event for order data
}) {
  return MostroMessage(
    action: Action.timeoutReversal, // ← Special action marking it as synthetic
    id: orderId,
    timestamp: timestamp,          // ← "Pretends" to have this timestamp
    payload: Order(
      status: Status.pending,      // ← The reverted state
      // ... complete order data extracted from real public event
    ),
  );
}
```

#### 2. **Unique Storage Key Pattern**

```dart
final messageKey = '${orderId}_timeout_$publicTimestamp';
//                    ^        ^        ^
//                    |        |        └─ Ensures uniqueness per timeout
//                    |        └─ Marks as synthetic timeout event  
//                    └─ Identifies the specific order
```

#### 3. **Database Storage Deception**

```dart
await storage.addMessage(messageKey, timeoutMessage);
```

The synthetic message is stored **exactly like a real message** in the Sembast database. When the app restarts:

1. **App loads all messages** from local storage
2. **Finds synthetic message** with `Action.timeoutReversal`
3. **"Thinks" it received** this message from Mostro
4. **Reconstructs order state** as pending due to timeout
5. **UI displays correctly** with cancel button enabled

### When Synthetic Events Are Created

#### ✅ **MAKER Scenario (Creates Synthetic Event)**
```
User Role: Order Creator
Timeout: waiting-buyer-invoice → pending
Action: 
  - Preserve session (keep in "My Trades")
  - Create synthetic timeout reversal message  
  - Update state to Status.pending + Action.timeoutReversal
Result: Order remains visible as pending after app restart
```

#### ❌ **TAKER Scenario (NO Synthetic Event)**
```  
User Role: Order Accepter
Timeout: waiting-payment → pending
Action:
  - Delete session completely
  - NO synthetic message created
  - Order disappears from "My Trades"
Result: Order returns to public Order Book for others to take
```

### Technical Implementation Details

#### **Storage Architecture**
- **Real Messages**: `${orderId}_${messageTimestamp}` keys
- **Synthetic Messages**: `${orderId}_timeout_${publicTimestamp}` keys  
- **Conflict Prevention**: Unique timeout prefix prevents key collisions

#### **Message Content**
The synthetic message contains **complete order information** extracted from the real public 38383 event:
- All order details (amount, payment method, premium)
- Original creation and expiration timestamps  
- Master pubkeys for reputation display
- Everything needed for proper UI rendering

#### **Recovery Process**
On app restart, synthetic messages are loaded and processed identically to real messages, ensuring seamless state recovery without any special handling required.

### Why It's Called a "Trick"

This approach is considered a "trick" because:

1. **🎭 Deception**: The app "lies" to itself about receiving a message
2. **🔄 Workaround**: Solves a persistence problem through simulation  
3. **💡 Clever**: Uses existing message infrastructure for artificial data
4. **🎯 Invisible**: Users never know the message is fake - it just works

The synthetic event system demonstrates how clever local state management can solve complex user experience problems in distributed systems where not all state transitions are explicitly communicated by the server.

---

## Error Handling and Resilience

### Race Condition Protection

The system implements multiple levels of protection against concurrent processing:

```dart
// Separate flags for different operations
bool _isSyncing = false;              // Only for sync() method  
bool _isProcessingTimeout = false;     // Only for timeout processing

// Protected timeout processing
if (_isProcessingTimeout) {
  logger.d('Timeout processing already in progress for order $orderId');
  return;
}

try {
  _isProcessingTimeout = true;
  // ... timeout detection logic
} finally {
  _isProcessingTimeout = false; // Always clean up
}
```

### Operation Timeouts

All critical operations include timeout protection:

```dart
// Session cleanup with timeout
await sessionNotifier.deleteSession(orderId)
    .timeout(const Duration(seconds: 5));

// Storage operations with timeout  
await storage.addMessage(messageKey, timeoutMessage)
    .timeout(const Duration(seconds: 8));
```

### Validation and Edge Cases

**Timestamp Validation**:
```dart
bool isValidTimestamp(int? timestamp) {
  if (timestamp == null || timestamp <= 0) return false;
  
  final now = DateTime.now();
  final messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
  
  // Reject future timestamps (with 1 hour tolerance for CI/network latency)
  if (messageTime.isAfter(now.add(const Duration(hours: 1)))) return false;
  
  // Reject very old timestamps (older than 7 days)
  if (messageTime.isBefore(now.subtract(const Duration(days: 7)))) return false;
  
  return true;
}
```

**State Validation**:
```dart
// Multiple state checks before processing
if (!mounted || currentSession == null) return;

if (state.status != Status.waitingBuyerInvoice && 
    state.status != Status.waitingPayment) return;
```

### Graceful Degradation

The system continues functioning even when individual operations fail:

- **Storage failures**: Continue execution, log errors
- **Network issues**: Retry logic with exponential backoff  
- **Provider disposal**: Proper cleanup prevents memory leaks
- **Invalid data**: Validation and fallback values

---

## Configuration and Customization

### Dynamic Configuration

The system uses dynamic configuration from the Mostro Instance Nostr event:

```dart
// Timeout durations from Mostro instance
final expHours = mostroInstance?.expirationHours ?? 24;       // Default 24h for pending
final expSecs = mostroInstance?.expirationSeconds ?? 900;     // Default 15min for waiting

// Session expiration
const sessionExpirationHours = 36; // Defined in Config class (lib/core/config.dart)
const cleanupIntervalMinutes = 30;  // Cleanup frequency
```

### Configurable Constants

```dart
// lib/core/config.dart
class Config {
  static const int sessionExpirationHours = 72;
}

// Timeout durations (currently hardcoded, could be made configurable)
static const Duration sessionCleanupTimeout = Duration(seconds: 5);
static const Duration storageOperationTimeout = Duration(seconds: 8);
```

### Internationalization

The system supports localized timeout notifications:

```dart
// lib/l10n/intl_*.arb files
{
  "orderTimeoutTaker": "You didn't respond in time. The order will be republished",
  "orderTimeoutMaker": "Your counterpart didn't respond in time. The order will be republished"
}

// Spanish
"orderTimeoutTaker": "No respondiste a tiempo. La orden será republicada"
"orderTimeoutMaker": "Tu contraparte no respondió a tiempo. La orden será republicada"

// Italian  
"orderTimeoutTaker": "Non hai risposto in tempo. L'ordine sarà ripubblicato"
"orderTimeoutMaker": "La tua controparte non ha risposto in tempo. L'ordine sarà ripubblicato"
```

---

## Development Guidelines

### Best Practices

**Session Access Pattern**:
```dart
// ✅ Correct - Use optimized provider pattern
final session = ref.read(sessionProvider(orderId));

// ❌ Avoid - Old pattern (inconsistent with main)
final session = ref.read(sessionNotifierProvider.notifier).getSessionByOrderId(orderId);
```

**Timeout Detection**:
- The system is fully automatic - no manual intervention needed
- Detection is status-based, not timestamp-based for reliability
- Always handle both maker and taker scenarios differently

**Error Handling**:
- Use timeout wrappers for all async operations
- Implement proper cleanup in finally blocks
- Validate all external data before processing

### Testing Considerations

**Key Test Scenarios**:
1. **Maker timeout**: Verify session preserved, state updated to pending
2. **Taker timeout**: Verify session deleted, order disappears from My Trades
3. **Synthetic event creation**: Verify artificial messages are created and stored correctly
4. **App restart recovery**: Verify synthetic events are loaded and processed like real messages
5. **Cancellation detection**: Verify proper session handling based on order state
6. **Race conditions**: Verify concurrent processing is prevented
7. **Invalid data**: Verify graceful handling of corrupt timestamps/events

**Mocking Strategy**:
- Mock orderEventsProvider for event simulation
- Mock sessionNotifierProvider for session state testing
- Mock time providers for countdown testing
- Use real timestamp validation functions (not constant expressions)

### Performance Considerations

**Optimization Points**:
- Timer debouncing prevents unnecessary UI updates
- Single timer supports multiple countdown subscribers
- Session provider optimization reduces lookup overhead
- Event filtering reduces processing of irrelevant events

**Memory Management**:
- Automatic timer cleanup when no listeners
- Proper provider disposal handling
- Session cleanup removes expired entries
- Race condition flags prevent resource leaks

---

## Related Documentation

### Implementation Files
- **`lib/features/order/notfiers/order_notifier.dart`** - Core timeout detection and synthetic event creation
- **`lib/data/models/mostro_message.dart`** - MostroMessage.createTimeoutReversal() factory
- **`lib/shared/providers/time_provider.dart`** - Countdown timer system  
- **`lib/shared/notifiers/session_notifier.dart`** - Session management
- **`lib/features/trades/screens/trade_detail_screen.dart`** - Countdown UI

---

## Orphan Session Prevention System

### Overview

A 10-second timeout cleanup system that prevents orphan sessions when Mostro instances are unresponsive or offline. This system works alongside the real-time timeout detection to provide comprehensive session management.

### Implementation

#### **10-Second Cleanup Timer**

When users take orders, a cleanup timer is automatically started to prevent sessions from becoming orphaned if Mostro doesn't respond:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart:286-305
static void startSessionTimeoutCleanup(String orderId, Ref ref) {
  // Cancel existing timer if any
  _sessionTimeouts[orderId]?.cancel();
  
  _sessionTimeouts[orderId] = Timer(const Duration(seconds: 10), () {
    try {
      ref.read(sessionNotifierProvider.notifier).deleteSession(orderId);
      Logger().i('Session cleaned up after 10s timeout: $orderId');
      
      // Show timeout message to user and navigate to order book
      _showTimeoutNotificationAndNavigate(ref);
    } catch (e) {
      Logger().e('Failed to cleanup session: $orderId', error: e);
    }
    _sessionTimeouts.remove(orderId);
  });
  
  Logger().i('Started 10s timeout timer for order: $orderId');
}
```

#### **Timer Cancellation on Response**

The cleanup timer is automatically cancelled when any response is received from Mostro:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart:92-93
void handleEvent(MostroMessage event) {
  // Cancel timer on ANY response from Mostro for this order
  _cancelSessionTimeoutCleanup(orderId);
  // ... rest of event handling
}
```

#### **Timer Integration in Order Taking**

The cleanup timer is started automatically when users take orders:

```dart
// lib/features/order/notfiers/order_notifier.dart:107-108
Future<void> takeSellOrder(String orderId, int? amount, String? lnAddress) async {
  // ... session creation
  
  // Start 10s timeout cleanup timer for phantom session prevention
  AbstractMostroNotifier.startSessionTimeoutCleanup(orderId, ref);
  
  await mostroService.takeSellOrder(orderId, amount, lnAddress);
}
```

### User Experience

#### **Timeout Notification and Navigation**

When the 10-second timer expires, users receive a localized notification and are automatically navigated back to the order book:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart:381-393
static void _showTimeoutNotificationAndNavigate(Ref ref) {
  try {
    // Show snackbar with localized timeout message
    final notificationNotifier = ref.read(notificationActionsProvider.notifier);
    notificationNotifier.showCustomMessage('sessionTimeoutMessage');
    
    // Navigate to main order book screen (home)
    final navProvider = ref.read(navigationProvider.notifier);
    navProvider.go('/');
  } catch (e) {
    Logger().e('Failed to show timeout notification or navigate', error: e);
  }
}
```

#### **Localized Messages**

The system includes localized timeout messages in all supported languages:

```json
// English
"sessionTimeoutMessage": "No response received, check your connection and try again later"

// Spanish  
"sessionTimeoutMessage": "No hubo respuesta, verifica tu conexión e inténtalo más tarde"

// Italian
"sessionTimeoutMessage": "Nessuna risposta ricevuta, verifica la tua connessione e riprova più tardi"
```

### Integration with Real-Time Detection

The orphan session prevention system works in conjunction with the real-time timeout detection:

1. **Real-time detection**: Monitors public events for status changes and handles timeouts immediately when detected
2. **30-second cleanup**: Acts as a fallback to prevent orphan sessions when Mostro is completely unresponsive
3. **Dual protection**: Ensures sessions are cleaned up either through real-time detection or automatic timeout

### Timer Management

#### **Static Timer Storage**

```dart
// Timer storage for phantom session cleanup
static final Map<String, Timer> _sessionTimeouts = {};
```

#### **Proper Cleanup on Disposal**

```dart
@override
void dispose() {
  subscription?.close();
  // Cancel timer for this specific orderId if it exists
  _sessionTimeouts[orderId]?.cancel();
  _sessionTimeouts.remove(orderId);
  super.dispose();
}
```

This ensures that timers are properly cleaned up when notifiers are disposed to prevent memory leaks.

**Last Updated**: September 15, 2025 

