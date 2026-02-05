# NostrService State Management System

## Overview

This document proposes a comprehensive state management system for NostrService to eliminate race conditions during Mostro instance switching. The current implementation causes "Nostr is not initialized" errors when services attempt to use NostrService during configuration updates.

## Current Problem Analysis

### The Race Condition

The current implementation in `NostrService.updateSettings()` creates a critical race condition:

```dart
Future<void> updateSettings(Settings newSettings) async {
  // PROBLEM: Immediately disables service
  _isInitialized = false;  // ← Services fail here
  
  // Asynchronous operations follow
  await _nostr.services.relays.disconnectFromRelays();
  await init(newSettings);  // ← Service becomes available again
}
```

### Error Sequence

```
t=0: _isInitialized = true (Normal operation)
t=1: User changes Mostro instance
t=2: _isInitialized = false (IMMEDIATE - synchronous)
t=3-10: Reinitialization in progress (ASYNCHRONOUS)
t=5: filteredTradesWithOrderStateProvider tries to access → ERROR
t=10: _isInitialized = true (Reinitialization complete)
```

### Impact on Application

- **User Experience**: Error dialogs during instance switching
- **Service Reliability**: Dependent services crash instead of waiting
- **State Corruption**: Providers may enter invalid states
- **Recovery Issues**: Manual app restart sometimes required

## Proposed Solution: State-Based Management System

### Core Concept

Replace the binary `_isInitialized` flag with a comprehensive state system that allows services to **wait** during transitions instead of failing.

### State Machine Design

```dart
enum NostrServiceState {
  uninitialized,    // Never been initialized
  initializing,     // First initialization in progress  
  ready,           // Available for normal operations
  updating,        // Configuration change in progress
  error           // Error state requiring intervention
}
```

### State Transitions

```
Startup Flow:
uninitialized → initializing → ready

Update Flow:
ready → updating → ready

Error Recovery:
error → initializing → ready
ready → updating → error
```

## Implementation Design

### 1. Core State Management

```dart
class NostrService {
  NostrServiceState _state = NostrServiceState.uninitialized;
  final List<Completer<void>> _waitingServices = [];
  final Logger _logger = Logger();
  
  // Public state accessors
  NostrServiceState get state => _state;
  bool get isReady => _state == NostrServiceState.ready;
  bool get isUpdating => _state == NostrServiceState.updating;
  bool get isUninitialized => _state == NostrServiceState.uninitialized;
  bool get hasError => _state == NostrServiceState.error;
  
  // Main waiting mechanism
  Future<void> waitForReady({Duration? timeout}) async {
    if (_state == NostrServiceState.ready) return;
    
    final completer = Completer<void>();
    _waitingServices.add(completer);
    
    if (timeout != null) {
      return completer.future.timeout(timeout, onTimeout: () {
        _waitingServices.remove(completer);
        throw TimeoutException('NostrService wait timeout', timeout);
      });
    }
    
    return completer.future;
  }
  
  // Notify all waiting services
  void _notifyWaitingServices() {
    final waiters = List.from(_waitingServices);
    _waitingServices.clear();
    
    for (final completer in waiters) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }
    
    _logger.i('Notified ${waiters.length} waiting services');
  }
  
  // Notify waiting services of error
  void _notifyWaitingServicesError(Object error) {
    final waiters = List.from(_waitingServices);
    _waitingServices.clear();
    
    for (final completer in waiters) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }
    
    _logger.e('Notified ${waiters.length} waiting services of error: $error');
  }
}
```

### 2. Initialization Methods

```dart
// Initial setup
Future<void> init(Settings settings) async {
  _state = NostrServiceState.initializing;
  _logger.i('NostrService initializing...');
  
  try {
    await _initializeWithSettings(settings);
    _state = NostrServiceState.ready;
    _notifyWaitingServices();
    _logger.i('NostrService ready');
  } catch (e) {
    _state = NostrServiceState.error;
    _notifyWaitingServicesError(e);
    _logger.e('NostrService initialization failed: $e');
    rethrow;
  }
}

// Configuration updates
Future<void> updateSettings(Settings newSettings) async {
  _logger.i('Starting Mostro instance update...');
  _state = NostrServiceState.updating;
  
  try {
    // Disconnect from current relays
    await _nostr.services.relays.disconnectFromRelays();
    _logger.i('Disconnected from previous relays');
    
    // Reinitialize with new settings
    await _initializeWithSettings(newSettings);
    
    // Transition to ready and notify waiters
    _state = NostrServiceState.ready;
    _notifyWaitingServices();
    _logger.i('Mostro instance update completed successfully');
    
  } catch (e) {
    _state = NostrServiceState.error;
    _notifyWaitingServicesError(e);
    _logger.e('Mostro instance update failed: $e');
    rethrow;
  }
}
```

### 3. Service Methods with State Awareness

```dart
// Core subscription method
Future<void> subscribeToEvents({
  required List<Map<String, dynamic>> filters,
  required void Function(NostrEvent) onEvent,
  String? subscriptionId,
}) async {
  // Wait if service is updating
  if (_state == NostrServiceState.updating) {
    _logger.d('NostrService updating, waiting for completion...');
    await waitForReady(timeout: const Duration(seconds: 30));
  }
  
  // Verify service is ready
  if (_state != NostrServiceState.ready) {
    throw NostrServiceException('NostrService not ready. Current state: $_state');
  }
  
  // Proceed with normal operation
  await _nostr.services.subscriptions.subscribe(
    filters: filters,
    onEvent: onEvent,
    subscriptionId: subscriptionId,
  );
}

// Event publishing
Future<void> publishEvent(NostrEvent event) async {
  await waitForReady(timeout: const Duration(seconds: 30));
  
  if (_state != NostrServiceState.ready) {
    throw NostrServiceException('Cannot publish: NostrService not ready');
  }
  
  await _nostr.services.events.publishEvent(event);
}

// Direct message sending
Future<void> sendDirectMessage({
  required String content,
  required String recipientPubkey,
  required String senderPrivkey,
}) async {
  await waitForReady(timeout: const Duration(seconds: 30));
  
  if (_state != NostrServiceState.ready) {
    throw NostrServiceException('Cannot send DM: NostrService not ready');
  }
  
  // Proceed with sending
  // ... implementation
}
```

### 4. Custom Exception Classes

```dart
class NostrServiceException implements Exception {
  final String message;
  final NostrServiceState? state;
  
  const NostrServiceException(this.message, {this.state});
  
  @override
  String toString() => 'NostrServiceException: $message${state != null ? ' (state: $state)' : ''}';
}

class NostrServiceTimeoutException extends NostrServiceException {
  final Duration timeout;
  
  const NostrServiceTimeoutException(String message, this.timeout, {NostrServiceState? state}) 
    : super(message, state: state);
  
  @override
  String toString() => 'NostrServiceTimeoutException: $message after ${timeout.inSeconds}s';
}
```

## Usage in Dependent Services

### 1. Repository Pattern

```dart
class OpenOrdersRepository {
  final NostrService _nostrService;
  
  Future<void> _subscribeToOrders() async {
    try {
      // Wait for NostrService if it's updating
      await _nostrService.waitForReady(timeout: const Duration(seconds: 30));
      
      // Now safe to subscribe
      await _nostrService.subscribeToEvents(
        filters: [/* order filters */],
        onEvent: _handleOrderEvent,
        subscriptionId: 'orders',
      );
      
      _logger.i('Successfully subscribed to orders');
    } catch (e) {
      _logger.e('Failed to subscribe to orders: $e');
      rethrow;
    }
  }
  
  Future<void> updateSettings(Settings newSettings) async {
    // Service will wait automatically during updates
    await _subscribeToOrders();
  }
}
```

### 2. Provider Integration

```dart
// Trades provider with state awareness
final filteredTradesWithOrderStateProvider = FutureProvider<List<TradeWithState>>((ref) async {
  final nostrService = ref.watch(nostrServiceProvider);
  
  // Wait for service to be ready
  await nostrService.waitForReady();
  
  final trades = await ref.watch(tradesProvider.future);
  final orderStates = await ref.watch(orderStatesProvider.future);
  
  // Proceed with filtering logic
  return trades.where((trade) {
    final orderState = orderStates[trade.orderId];
    return orderState != null && orderState.status != Status.canceled;
  }).toList();
});

// Alternative with error handling
final safeFilteredTradesProvider = Provider<AsyncValue<List<TradeWithState>>>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  
  // Check service state
  switch (nostrService.state) {
    case NostrServiceState.uninitialized:
    case NostrServiceState.initializing:
    case NostrServiceState.updating:
      return const AsyncValue.loading();
      
    case NostrServiceState.error:
      return AsyncValue.error('NostrService error', StackTrace.current);
      
    case NostrServiceState.ready:
      return ref.watch(filteredTradesWithOrderStateProvider);
  }
});
```

### 3. Background Services Integration

```dart
class BackgroundNotificationService {
  final NostrService _nostrService;
  
  Future<void> _initialize() async {
    // Wait for main NostrService to be ready
    await _nostrService.waitForReady(timeout: const Duration(minutes: 1));
    
    // Setup background subscriptions
    await _subscribeToNotifications();
  }
  
  Future<void> handleMostroInstanceChange() async {
    _logger.i('Handling Mostro instance change in background service');
    
    // Wait for update to complete
    await _nostrService.waitForReady();
    
    // Resubscribe with new instance
    await _subscribeToNotifications();
  }
}
```

## Benefits Analysis

### 1. Eliminated Race Conditions

**Before:**
```
Mostro Change → _isInitialized = false → Service Call → ERROR
```

**After:**
```
Mostro Change → state = updating → Service Call → waitForReady() → Update Complete → Continue
```

### 2. Graceful Service Degradation

- **No Hard Failures**: Services wait instead of crashing
- **Transparent Recovery**: Automatic continuation after updates
- **User Experience**: No error dialogs during instance switching
- **Predictable Behavior**: Clear state transitions

### 3. Better Error Handling

```dart
// Clear error states and messages
try {
  await nostrService.subscribeToEvents(...);
} catch (NostrServiceException e) {
  // Handle specific NostrService errors
  _logger.e('NostrService error: ${e.message}');
} catch (NostrServiceTimeoutException e) {
  // Handle timeout scenarios
  _logger.e('NostrService timeout after ${e.timeout}');
}
```

### 4. Multiple Concurrent Waiters

```dart
// Multiple services can wait simultaneously
final futures = [
  tradesRepository.updateSubscriptions(),
  ordersRepository.updateSubscriptions(), 
  chatRepository.updateSubscriptions(),
];

// All resolve when update completes
await Future.wait(futures);
```

### 5. Observable State Changes

```dart
// Providers can react to state changes
final nostrServiceStateProvider = Provider<NostrServiceState>((ref) {
  return ref.watch(nostrServiceProvider).state;
});

// UI can show loading indicators
final isNostrUpdatingProvider = Provider<bool>((ref) {
  final state = ref.watch(nostrServiceStateProvider);
  return state == NostrServiceState.updating || state == NostrServiceState.initializing;
});
```

## Drawbacks and Considerations

### 1. Increased Complexity

**Added Complexity:**
- State machine logic
- Completer management
- Timeout handling
- Additional exception types

**Mitigation:**
- Well-documented state transitions
- Clear error messages
- Comprehensive testing
- Gradual migration path

### 2. Memory Overhead

**Potential Issues:**
- List of waiting Completers
- State tracking variables
- Additional logging

**Impact Assessment:**
- Minimal memory usage (few KB)
- Completers are short-lived
- Automatic cleanup after completion

### 3. Timeout Management

**Challenges:**
- Choosing appropriate timeout values
- Handling timeout scenarios
- Balancing responsiveness vs reliability

**Proposed Timeouts:**
- Default: 30 seconds for normal operations
- Extended: 60 seconds for initialization
- Background: 2 minutes for non-critical operations

### 4. Error Recovery Complexity

**Scenarios to Handle:**
- Network failures during updates
- Invalid Mostro configurations
- Relay connection issues
- Timeout during state transitions

**Recovery Strategies:**
- Automatic retry with exponential backoff
- Fallback to previous working configuration
- User notification with manual retry option
- Graceful degradation to offline mode

### 5. Testing Challenges

**Testing Requirements:**
- State transition testing
- Concurrent waiter scenarios
- Timeout behavior verification
- Error state recovery testing
- Race condition simulation

**Testing Strategy:**
```dart
// Example test structure
group('NostrService State Management', () {
  testWidgets('should wait during updates', (tester) async {
    final service = NostrService();
    await service.init(testSettings);
    
    // Start update
    final updateFuture = service.updateSettings(newSettings);
    
    // Verify state is updating
    expect(service.state, NostrServiceState.updating);
    
    // Service call should wait
    final waitFuture = service.subscribeToEvents(...);
    
    // Complete update
    await updateFuture;
    
    // Wait should resolve
    await waitFuture;
    expect(service.state, NostrServiceState.ready);
  });
});
```

## Performance Impact Analysis

### 1. Latency Considerations

**Normal Operations:**
- Ready state: No additional latency
- Single state check: ~1μs overhead

**During Updates:**
- Wait duration: Depends on network and configuration
- Typical update time: 2-5 seconds
- Maximum with timeout: 30 seconds

### 2. Memory Usage

**State Management:**
- State enum: 4 bytes
- Completer list: ~24 bytes per waiter
- Typical concurrent waiters: 3-10
- Total overhead: <1KB

### 3. CPU Impact

**State Transitions:**
- Enum comparison: O(1)
- Completer resolution: O(n) where n = waiting services
- Typical n: <10, negligible impact

### 4. Network Efficiency

**Connection Management:**
- Reuses existing connections when possible
- Graceful disconnection/reconnection
- No redundant subscription attempts

## Migration Strategy

### Phase 1: Core Implementation

1. **Add State Enum**: Implement `NostrServiceState` enum
2. **State Management**: Add state tracking and transition logic
3. **Waiting Mechanism**: Implement `waitForReady()` method
4. **Update Methods**: Modify `init()` and `updateSettings()`

### Phase 2: Service Integration

1. **Core Services**: Update `subscribeToEvents()` and publishing methods
2. **Repository Layer**: Modify repositories to use waiting mechanism
3. **Background Services**: Update background notification service

### Phase 3: Provider Updates

1. **Provider Dependencies**: Update providers to handle state changes
2. **Error Handling**: Implement proper error boundaries
3. **UI Indicators**: Add loading states for service updates

### Phase 4: Testing and Validation

1. **Unit Tests**: Comprehensive state transition testing
2. **Integration Tests**: Multi-service interaction testing
3. **Performance Tests**: Latency and memory impact validation
4. **User Testing**: Real-world scenario validation

## Alternative Approaches

### 1. Simple Flag-Based Approach

```dart
bool _isUpdating = false;

Future<void> subscribeToEvents(...) async {
  while (_isUpdating) {
    await Future.delayed(Duration(milliseconds: 100));
  }
  // Proceed normally
}
```

**Pros:**
- Simpler implementation
- Lower memory overhead
- Easier to understand

**Cons:**
- Polling-based (inefficient)
- No timeout handling
- Poor error recovery
- No state observability

### 2. Event-Based Approach

```dart
final StreamController<NostrServiceEvent> _eventController = StreamController.broadcast();

Future<void> waitForReady() async {
  await _eventController.stream
    .where((event) => event is ServiceReadyEvent)
    .first;
}
```

**Pros:**
- Reactive patterns
- Good for multiple listeners
- Clear event semantics

**Cons:**
- Stream management complexity
- Memory leaks potential
- Subscription lifecycle management

### 3. Provider-Based State Management

```dart
final nostrServiceStateProvider = StateNotifierProvider<NostrServiceStateNotifier, NostrServiceState>((ref) {
  return NostrServiceStateNotifier();
});
```

**Pros:**
- Integrates with existing Riverpod architecture
- Automatic dependency invalidation
- UI-friendly state updates

**Cons:**
- Tighter coupling to Riverpod
- Complex provider dependency chains
- Harder to unit test

## Recommended Implementation

### Primary Approach: State-Based Management

The proposed state-based system with the `waitForReady()` mechanism is recommended because:

1. **Comprehensive**: Handles all identified scenarios
2. **Performant**: Minimal overhead with immediate resolution
3. **Testable**: Clear state transitions and deterministic behavior
4. **Maintainable**: Well-defined API and error handling
5. **Scalable**: Supports multiple concurrent waiters efficiently

### Fallback Strategy

If the full state system proves too complex, implement the simpler flag-based approach initially, then migrate to the complete system:

```dart
// Phase 1: Simple flag
bool _isUpdating = false;

// Phase 2: Migrate to full state system
NostrServiceState _state = NostrServiceState.ready;
```

## Testing Strategy

### 1. Unit Tests

```dart
group('NostrService State Management', () {
  late NostrService service;
  
  setUp(() {
    service = NostrService();
  });
  
  test('should initialize correctly', () async {
    expect(service.state, NostrServiceState.uninitialized);
    
    await service.init(testSettings);
    
    expect(service.state, NostrServiceState.ready);
    expect(service.isReady, true);
  });
  
  test('should handle concurrent waiters', () async {
    await service.init(testSettings);
    
    // Start update
    final updateFuture = service.updateSettings(newSettings);
    
    // Multiple services wait
    final waiters = List.generate(5, (_) => service.waitForReady());
    
    // Complete update
    await updateFuture;
    
    // All waiters should resolve
    await Future.wait(waiters);
    expect(service.state, NostrServiceState.ready);
  });
  
  test('should handle timeout', () async {
    await service.init(testSettings);
    
    // Mock long update
    service.updateSettings(newSettings); // Don't await
    
    // Wait with short timeout should fail
    expect(
      () => service.waitForReady(timeout: Duration(milliseconds: 100)),
      throwsA(isA<TimeoutException>()),
    );
  });
});
```

### 2. Integration Tests

```dart
testWidgets('should handle Mostro instance change gracefully', (tester) async {
  // Setup app with initial Mostro instance
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle();
  
  // Navigate to settings
  await tester.tap(find.byKey(Key('settingsButton')));
  await tester.pumpAndSettle();
  
  // Change Mostro instance
  await tester.tap(find.byKey(Key('mostroInstanceSelector')));
  await tester.pumpAndSettle();
  
  // Select new instance
  await tester.tap(find.text('New Mostro Instance'));
  await tester.pumpAndSettle();
  
  // Verify no errors occurred
  expect(find.byType(ErrorWidget), findsNothing);
  
  // Verify services are working
  await tester.tap(find.byKey(Key('tradesTab')));
  await tester.pumpAndSettle();
  
  expect(find.byType(TradesList), findsOneWidget);
});
```

### 3. Performance Tests

```dart
test('should complete state transitions within acceptable time', () async {
  final stopwatch = Stopwatch()..start();
  
  await service.init(testSettings);
  expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5s max
  
  stopwatch.reset();
  await service.updateSettings(newSettings);
  expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // 10s max
});
```

## Conclusion

The proposed state-based management system provides a robust solution to the "Nostr is not initialized" error while improving overall system reliability. The implementation offers:

### Key Benefits

1. **Eliminates Race Conditions**: Services wait instead of failing
2. **Improved User Experience**: No error dialogs during instance changes
3. **Better Error Handling**: Clear state-based error management
4. **Enhanced Observability**: State changes are trackable and debuggable
5. **Future-Proof Architecture**: Extensible for additional states and behaviors

### Implementation Priority

**High Priority:**
- Core state management implementation
- Service method updates with waiting logic
- Repository layer integration

**Medium Priority:**
- Provider state awareness
- UI loading indicators
- Comprehensive error handling

**Low Priority:**
- Advanced timeout strategies
- Performance optimizations
- Enhanced observability features

### Success Metrics

- **Zero "Nostr is not initialized" errors** during Mostro instance switching
- **Sub-10 second** typical update completion times
- **100% success rate** for concurrent service operations during updates
- **No memory leaks** from waiting mechanism
- **Backward compatibility** with existing code

The proposed system transforms a critical reliability issue into a robust, maintainable, and user-friendly experience while preparing the architecture for future enhancements.

---

**Related Documentation:**
- [Timeout Cleanup Refactor](TIMEOUT_CLEANUP_REFACTOR.md)
- [Session Management Architecture](SESSION_AND_KEY_MANAGEMENT.md)
- [App Initialization Analysis](APP_INITIALIZATION_ANALYSIS.md)

**Last Updated**: September 23, 2025
**Status**: Proposal - Ready for Implementation
**Review Required**: Architecture Team