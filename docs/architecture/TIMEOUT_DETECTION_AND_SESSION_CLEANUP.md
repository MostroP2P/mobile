# Session and Order Lifecycle Management - Mostro Mobile

## Overview

This document provides comprehensive technical documentation for Mostro Mobile's session and order lifecycle management system. The implementation handles timeout detection, order cancellation, session cleanup, and real-time countdown timers for trading operations.

**Purpose**: Technical reference for understanding the complete lifecycle management of trading sessions and orders.

**Scope**: Covers timeout detection system, session management patterns, countdown timer architecture, and gift wrap-based communication handling.

---

## System Architecture

### Core Components

The lifecycle management system consists of four main components:

1. **OrderNotifier** - Direct gift wrap handling and session cleanup
2. **SessionNotifier** - Session lifecycle management and storage
3. **Time Provider System** - Optimized countdown timers
4. **UI Integration** - Real-time countdown display and notifications

### Communication Architecture

The system uses encrypted gift wrap messages for all timeout and cancellation handling:

#### **Gift Wrap Channel (SubscriptionManager)**
- **Purpose**: Handles all encrypted communications including timeout/cancellation instructions
- **Events**: Kind 1059 (encrypted gift-wrapped messages)
- **Usage**: "My Trades" data, private messaging, session state updates, timeout/cancellation notifications

#### **Public Channel (OpenOrdersRepository)**  
- **Purpose**: Handles public order discovery for Order Book display
- **Events**: Kind 38383 (public Mostro order events)
- **Usage**: Order Book display only (no timeout detection)

---

## Timeout Detection System

### Gift Wrap-Based Detection Architecture

The timeout detection system receives direct instructions from Mostro via encrypted gift wrap messages (kind 1059) and automatically handles timeouts and cancellations based on user role (maker vs taker).

#### **OrderNotifier Implementation**

```dart
// lib/features/order/notfiers/order_notifier.dart
class OrderNotifier extends AbstractMostroNotifier {
  // Simplified implementation - timeout/cancellation logic moved to AbstractMostroNotifier
  @override
  Future<void> handleEvent(MostroMessage event, {bool bypassTimestampGate = false}) async {
    // Handle the event normally - timeout/cancellation logic is now in AbstractMostroNotifier
    await super.handleEvent(event, bypassTimestampGate: bypassTimestampGate);
  }
}
```

**Key Features**:
- **Direct gift wrap handling**: Receives explicit timeout/cancellation instructions from Mostro
- **Automatic cleanup**: Handles session deletion vs preservation based on user role
- **Simplified logic**: No complex public event monitoring or timestamp comparisons

### Direct Gift Wrap Handling

The system processes timeout and cancellation instructions directly from Mostro via gift wrap messages:

#### **AbstractMostroNotifier Gift Wrap Processing**

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart
Future<void> handleEvent(MostroMessage event, {bool bypassTimestampGate = false}) async {
  switch (event.action) {
    case Action.newOrder:
      // Check if this is a timeout reactivation from Mostro
      final currentSession = ref.read(sessionProvider(orderId));
      if (currentSession != null && 
          (state.status == Status.waitingBuyerInvoice || state.status == Status.waitingPayment)) {
        // This is a maker receiving order reactivation after taker timeout
        logger.i('MAKER: Received order reactivation from Mostro - taker timed out, order returned to pending');
        
        // Show notification: counterpart didn't respond, order will be republished
        if (isRecent || !bypassTimestampGate) {
          final notifProvider = ref.read(notificationActionsProvider.notifier);
          notifProvider.showCustomMessage('orderTimeoutMaker');
        }
      }
      break;
      
    case Action.canceled:
      // Handle cancellation sent by Mostro (for both timeout and cancellation scenarios)
      final currentSession = ref.read(sessionProvider(orderId));
      if (currentSession != null) {
        logger.i('CANCELLATION: Received cancellation message from Mostro for order $orderId');
        
        // Delete session - this applies to both maker and taker scenarios
        final sessionNotifier = ref.read(sessionNotifierProvider.notifier);
        await sessionNotifier.deleteSession(orderId);
        
        logger.i('Session deleted for canceled order $orderId');
        
        // Show cancellation notification
        if (isRecent || !bypassTimestampGate) {
          final notifProvider = ref.read(notificationActionsProvider.notifier);
          notifProvider.showCustomMessage('orderCanceled');
        }
        
        // Navigate to main order book screen
        if (isRecent && !bypassTimestampGate) {
          navProvider.go('/');
        }
        
        return; // Session was deleted, no further processing needed
      }
      break;
  }
}
```

### Gift Wrap-Based Detection Logic

The system receives explicit instructions from Mostro instead of inferring timeouts from public events:

#### **Direct Instruction Processing**

**Timeout Detection**:
- **Mostro sends `Action.newOrder`** to makers when taker times out
- **Mostro sends `Action.canceled`** to takers when they time out
- **No timestamp comparison needed** - Mostro decides and instructs directly
- **No synthetic message creation** - real gift wrap messages contain all needed information

**Cancellation Detection**:
- **Mostro sends `Action.canceled`** for all cancellation scenarios
- **Session handling based on current state** - preserves active orders, deletes pending/waiting orders
- **Universal handling** - same logic applies to timeouts and manual cancellations

### Maker vs Taker Differentiation

The system handles timeout scenarios differently based on the gift wrap action received:

#### **Behavior by Gift Wrap Action**

**MAKER (Order Creator) - Receives `Action.newOrder`**:
```
1. User creates order → Someone takes it → waiting state in My Trades
2. Taker doesn't respond → Mostro sends Action.newOrder gift wrap to maker
3. System preserves session and updates state to pending
4. Notification: "Your counterpart didn't respond in time"
5. Order stays in My Trades as pending, ready for someone else to take
```

**TAKER (Order Accepter) - Receives `Action.canceled`**:
```
1. User takes order → Order appears in My Trades with waiting state
2. User doesn't respond in time → Mostro sends Action.canceled gift wrap to taker
3. System deletes session completely
4. Notification: "Order was canceled"
5. Order disappears from My Trades and returns to Order Book for others to take
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

### Dynamic Countdown Timer System

The application now uses a unified `DynamicCountdownWidget` for all pending order countdown timers, providing intelligent scaling and precise timestamp calculations.

#### **DynamicCountdownWidget Architecture**

```dart
// lib/shared/widgets/dynamic_countdown_widget.dart
class DynamicCountdownWidget extends ConsumerWidget {
  final DateTime expiration;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remainingTime = expiration.isAfter(now) ? expiration.difference(now) : Duration.zero;
    final useDayScale = remainingTime.inHours > 24;

    if (useDayScale) {
      // Day scale: "14d 20h 06m" format for >24 hours
      final daysLeft = (remainingTime.inHours / 24).floor();
      final hoursLeftInDay = remainingTime.inHours % 24;
      final minutesLeftInHour = remainingTime.inMinutes % 60;
      return CircularCountdown(countdownTotal: totalDays, countdownRemaining: daysLeft);
    } else {
      // Hour scale: "HH:MM:SS" format for ≤24 hours
      final hoursLeft = remainingTime.inHours.clamp(0, totalHours);
      final minutesLeft = remainingTime.inMinutes % 60;
      final secondsLeft = remainingTime.inSeconds % 60;
      return CircularCountdown(countdownTotal: totalHours, countdownRemaining: hoursLeft);
    }
  }
}
```

#### **Key Features**

1. **Automatic Scaling**: Switches between day/hour formats based on remaining time
2. **Exact Timestamps**: Uses `expires_at` tag for precise calculations
3. **Dynamic Display**: 
   - **>24 hours**: Day scale with "14d 20h 06m" format
   - **≤24 hours**: Hour scale with "HH:MM:SS" format
4. **Intelligent Rounding**: Circle divisions use intelligent rounding (28.2h → 28h, 23.7h → 24h)
5. **Shared Component**: Eliminates 96 lines of duplicated countdown code

#### **Integration Points**

**TakeOrderScreen Usage**:
```dart
// lib/features/order/screens/take_order_screen.dart - _buildCountDownTime method
return DynamicCountdownWidget(
  expiration: DateTime.fromMillisecondsSinceEpoch(expiresAtTimestamp * 1000),
  createdAt: order.createdAt!,
);
```

**TradeDetailScreen Usage**:
```dart
// lib/features/trades/screens/trade_detail_screen.dart - trade details widget tree
_CountdownWidget(
  orderId: orderId,
  tradeState: tradeState,
  expiresAtTimestamp: orderPayload.expiresAt != null ? orderPayload.expiresAt! * 1000 : null,
),
```

#### **Scope and Limitations**

- **Pending Orders Only**: DynamicCountdownWidget is specifically designed for orders in `Status.pending`
- **Waiting Orders Use Different System**: Orders in `Status.waitingBuyerInvoice` and `Status.waitingPayment` use separate countdown logic based on `expirationSeconds` + message timestamps
- **Data Source**: Uses `expires_at` Nostr tag for exact expiration timestamps rather than calculated values

#### **Real-time Countdown Widget**

```dart
// lib/features/trades/screens/trade_detail_screen.dart - _CountdownWidget class
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
// _buildCountDownTime method: Countdown logic by order status
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
// _findMessageForState method: Find the message that caused the current state
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

## Gift Wrap Communication Architecture

### Direct Mostro Communication

The system receives timeout and cancellation instructions directly from Mostro via encrypted gift wrap messages:

#### **Gift Wrap Message Handling**

```dart
// All timeout/cancellation handling flows through SubscriptionManager
// which processes encrypted Kind 1059 events and delivers them to OrderNotifier
// via the existing mostroMessageStreamProvider system
```

#### **Public Event Providers (Order Book Only)**

Public events are now only used for Order Book display, not timeout detection:

```dart
// lib/shared/providers/order_repository_provider.dart
final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.read(orderRepositoryProvider);
  return orderRepository.eventsStream; // Stream of 38383 public events - ORDER BOOK ONLY
});
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
- **OrderNotifier**: Handles gift wrap message processing and session cleanup
- **OrderState**: Maintains current order state and action
- **SubscriptionManager**: Delivers encrypted timeout/cancellation messages

---

## Data Flow and Integration

### Complete Gift Wrap Flow

```
1. Order in waiting state (waitingBuyerInvoice or waitingPayment)
2. Timeout occurs on Mostro server
3. Mostro sends direct gift wrap message:
   - Action.newOrder to maker (timeout reactivation)
   - Action.canceled to taker (timeout cancellation)
4. SubscriptionManager receives and decrypts gift wrap
5. OrderNotifier.handleEvent() processes the instruction
6. System applies appropriate action based on gift wrap content
7. UI updates automatically through Riverpod reactive system
```

### State Management Flow

```dart
// Complete reactive chain
Gift Wrap (1059) → SubscriptionManager → mostroMessageStreamProvider → OrderNotifier
                                                                      ↓
Session state ← sessionNotifier.deleteSession() ← gift wrap instruction processing
     ↓
sessionProvider(orderId) → UI components → automatic updates
```

### Persistence and Recovery

**Session Persistence**: Sessions are stored in Sembast database and survive app restarts.

**Gift Wrap Message Persistence**: All gift wrap messages (including timeout/cancellation instructions) are automatically persisted by the existing message storage system, ensuring proper state recovery after app restart without requiring synthetic messages.


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

A comprehensive 10-second timeout cleanup system that prevents orphan sessions when Mostro instances are unresponsive or offline. This system provides dual protection for both order creation and order taking scenarios, working alongside the real-time timeout detection to provide comprehensive session management.

### Implementation

#### **10-Second Cleanup Timer**

The system automatically starts cleanup timers for both order creation and order taking scenarios to prevent sessions from becoming orphaned if Mostro doesn't respond:

**Order Taking Protection**:
When users take orders, a cleanup timer is automatically started to prevent sessions from becoming orphaned if Mostro doesn't respond:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart - startSessionTimeoutCleanup method
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

**Order Creation Protection**:
When users create new orders, a similar cleanup timer prevents orphan sessions if Mostro doesn't respond to the order creation request:

```dart
// lib/features/order/notfiers/abstract_mostro_notifier.dart
static void startSessionTimeoutCleanupForRequestId(int requestId, Ref ref) {
  final key = 'request:$requestId';
  // Cancel existing timer if any
  _sessionTimeouts[key]?.cancel();
  
  _sessionTimeouts[key] = Timer(const Duration(seconds: 10), () {
    try {
      ref.read(sessionNotifierProvider.notifier).deleteSessionByRequestId(requestId);
      Logger().i('Session cleaned up after 10s timeout for requestId: $requestId');
      
      // Show timeout message to user and navigate to order book
      _showTimeoutNotificationAndNavigate(ref);
    } catch (e) {
      Logger().e('Failed to cleanup session for requestId: $requestId', error: e);
    }
    _sessionTimeouts.remove(key);
  });
  
  Logger().i('Started 10s timeout timer for requestId: $requestId');
}
```

#### **Timer Integration**

**Order Taking**:
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

**Order Creation**:
The cleanup timer is started automatically when users create orders:

```dart
// lib/features/order/notfiers/add_order_notifier.dart
Future<void> submitOrder(Order order) async {
  // ... session creation
  
  // Start 10s timeout cleanup timer for create orders
  AbstractMostroNotifier.startSessionTimeoutCleanupForRequestId(requestId, ref);
  
  await mostroService.submitOrder(message);
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

### Integration with Gift Wrap Detection

The orphan session prevention system works in conjunction with the gift wrap-based timeout detection:

1. **Gift wrap detection**: Processes direct timeout/cancellation instructions from Mostro via encrypted messages
2. **10-second cleanup**: Acts as a fallback to prevent orphan sessions when Mostro is completely unresponsive
3. **Dual protection**: Ensures sessions are cleaned up either through gift wrap instructions or automatic timeout
4. **Differentiated handling**: Order creation uses `requestId`-based cleanup while order taking uses `orderId`-based cleanup

### Timer Management

#### **Static Timer Storage**

```dart
// Timer storage for phantom session cleanup
// Keys: orderId for order taking, 'request:requestId' for order creation
static final Map<String, Timer> _sessionTimeouts = {};
```

#### **Proper Cleanup on Disposal**

```dart
// For OrderNotifier (order taking)
@override
void dispose() {
  subscription?.close();
  // Cancel timer for this specific orderId if it exists
  _sessionTimeouts[orderId]?.cancel();
  _sessionTimeouts.remove(orderId);
  super.dispose();
}

// For AddOrderNotifier (order creation)
@override
void dispose() {
  // Cancel timer for requestId when notifier is disposed
  AbstractMostroNotifier.cancelSessionTimeoutCleanupForRequestId(requestId);
  super.dispose();
}
```

This ensures that timers are properly cleaned up when notifiers are disposed to prevent memory leaks, with differentiated cleanup methods for each session type.

### Key Differences: Order Creation vs Order Taking

| **Aspect** | **Order Taking** | **Order Creation** |
|------------|------------------|-------------------|
| **Timer Method** | `startSessionTimeoutCleanup(orderId, ref)` | `startSessionTimeoutCleanupForRequestId(requestId, ref)` |
| **Cleanup Method** | `deleteSession(orderId)` | `deleteSessionByRequestId(requestId)` |
| **Timer Key** | `orderId` | `'request:${requestId}'` |
| **Session Type** | Permanent (stored in database) | Temporary (memory only) |
| **Storage Impact** | Deletes from Sembast database | Removes from memory map only |
| **Use Case** | Taking existing orders | Creating new orders |

**Last Updated**: October 8, 2025 

