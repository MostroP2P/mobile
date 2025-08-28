# Mostro Mobile App Initialization Process

## Overview

This document provides a comprehensive technical guide to the Mostro Mobile app initialization process, detailing how the application bootstraps its core systems, establishes Nostr connectivity, and prepares for trading operations.

**Purpose**: Understanding the complete initialization flow enables developers to maintain, extend, and troubleshoot the app's startup sequence effectively.

**Scope**: Covers the entire startup process from app launch to ready-for-trading state, including system dependencies, architecture patterns, and integration points.

---

## App Initialization Sequence

### Core Initialization Flow

The Mostro Mobile app follows a carefully orchestrated initialization sequence managed by `appInitializerProvider`. This sequence ensures all systems are properly configured and connected before user interaction begins.

```dart
// lib/shared/providers/app_init_provider.dart
final appInitializerProvider = FutureProvider<void>((ref) async {
  // 1. Initialize NostrService
  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init(ref.read(settingsProvider));

  // 2. Initialize KeyManager  
  final keyManager = ref.read(keyManagerProvider);
  await keyManager.init();

  // 3. Initialize SessionNotifier - Load active trading sessions
  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();
  
  // 4. Create SubscriptionManager - Setup event subscriptions based on sessions
  ref.read(subscriptionManagerProvider);

  // 5. Configure background services for notifications and sync
  ref.listen<Settings>(settingsProvider, (previous, next) {
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  // 6. Initialize order notifiers for existing sessions
  final cutoff = DateTime.now().subtract(const Duration(hours: Config.sessionExpirationHours));
  for (final session in sessionManager.sessions) {
    if(session.orderId == null || session.startTime.isBefore(cutoff)) continue;
    
    ref.read(orderNotifierProvider(session.orderId!).notifier);
    
    if (session.peer != null) {
      ref.read(chatRoomsProvider(session.orderId!).notifier).subscribe();
    }
  }
});
```

---

## Detailed Component Analysis

### 1. NostrService Initialization

**Purpose**: Establishes WebSocket connections to Nostr relays.

**Process**:
```dart
// lib/services/nostr_service.dart:35
await nostrService.init(settings);
```

**What Happens**:
- Reads relay configuration from settings
- Establishes WebSocket connections to configured relays
- Sets up connection pool for Nostr protocol communication
- Validates relay connectivity

**Dependencies**: Settings (relay configuration)
**Duration**: ~200ms (network dependent)

### 2. KeyManager Initialization

**Purpose**: Initializes cryptographic key management system.

**Process**:
```dart
// lib/features/key_manager/key_manager_provider.dart
await keyManager.init();
```

**What Happens**:
- Loads master keys from secure storage
- Initializes hierarchical key derivation
- Sets up trade-specific key generation
- Validates key integrity

**Dependencies**: Secure storage access
**Duration**: ~50ms

### 3. SessionNotifier Initialization (CRITICAL)

**Purpose**: Loads all active trading sessions from local storage.

**Process**:
```dart
// lib/shared/notifiers/session_notifier.dart:32
await sessionManager.init();
```

**What Happens**:
```dart
Future<void> init() async {
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
  
  state = sessions; // This triggers listeners
  _scheduleCleanup();
}
```

**Critical Aspects**:
- Loads sessions from Sembast database
- Filters expired sessions (older than 72 hours)
- Updates `state` which triggers all listeners
- **Must complete before SubscriptionManager setup**

**Dependencies**: Session storage (Sembast database)
**Duration**: ~100ms (database I/O dependent)

### 4. SubscriptionManager Creation (THE FIX)

**Purpose**: Manages Nostr event subscriptions based on active sessions.

**Process**:
```dart
// lib/features/subscriptions/subscription_manager.dart:32
SubscriptionManager(this.ref) {
  _initSessionListener();
}

void _initSessionListener() {
  _sessionListener = ref.listen<List<Session>>(
    sessionNotifierProvider,
    (previous, current) {
      _updateAllSubscriptions(current);
    },
    fireImmediately: false, // ← THE FIX: Was 'true', causing race condition
    onError: (error, stackTrace) {
      _logger.e('Error in session listener', error: error, stackTrace: stackTrace);
    },
  );
}
```

**What The Fix Changes**:

**BEFORE (Problematic - fireImmediately: true)**:
```
1. SubscriptionManager constructor called
2. _initSessionListener() runs
3. fireImmediately: true → Listener executes IMMEDIATELY
4. sessionNotifierProvider.state is still [] (empty - SessionNotifier.init() hasn't run yet)
5. _updateAllSubscriptions([]) called
6. "No sessions available, clearing all subscriptions" logged
7. All subscriptions cleared
8. SessionNotifier.init() runs later and loads sessions
9. UI shows empty orders because subscriptions were cleared
```

**AFTER (Fixed - fireImmediately: false)**:
```
1. SubscriptionManager constructor called
2. _initSessionListener() runs  
3. fireImmediately: false → Listener registered but NOT executed
4. SessionNotifier.init() runs and loads sessions
5. sessionNotifierProvider.state updated to [session1, session2, ...]
6. Listener triggers for first time with actual sessions
7. _updateAllSubscriptions([session1, session2, ...]) called
8. "Subscription created for SubscriptionType.orders with X sessions" logged
9. UI shows orders correctly
```

**Dependencies**: SessionNotifier state
**Duration**: Instantaneous (just creates listener)

### 5. Background Services Setup

**Purpose**: Configures notification and background processing services.

**Process**:
```dart
ref.listen<Settings>(settingsProvider, (previous, next) {
  ref.read(backgroundServiceProvider).updateSettings(next);
});
```

**What Happens**:
- Sets up listener for settings changes
- Configures notification delivery
- Initializes background sync processes

**Dependencies**: Settings provider
**Duration**: ~10ms

### 6. Order Notifier Initialization

**Purpose**: Creates individual order management notifiers for each active session.

**Process**:
```dart
for (final session in sessionManager.sessions) {
  if(session.orderId == null || session.startTime.isBefore(cutoff)) continue;
  
  // Create order notifier for this session
  ref.read(orderNotifierProvider(session.orderId!).notifier);
  
  // Initialize chat if peer exists
  if (session.peer != null) {
    ref.read(chatRoomsProvider(session.orderId!).notifier).subscribe();
  }
}
```

**What Happens**:
- Iterates through all loaded sessions
- Creates `OrderNotifier` for each active order
- Sets up chat room subscriptions for orders with assigned peers
- Establishes timeout detection and reversal systems

**Dependencies**: SessionNotifier state, ChatRoomProvider
**Duration**: ~50ms per session

---

## Initialization Dependencies & Timing

### Why Order Matters

The initialization sequence has critical timing dependencies that must be respected:

- **SessionNotifier must complete before SubscriptionManager**: Event subscriptions require loaded session data to create proper filters
- **NostrService must initialize first**: Other components depend on established relay connectivity  
- **KeyManager initializes early**: Required for session restoration and cryptographic operations

### Common Timing Patterns

#### **Dependent Provider Initialization**
```dart
// Correct pattern for dependent initialization
_sessionListener = ref.listen<List<Session>>(
  sessionNotifierProvider,
  (previous, current) => _updateSubscriptions(current),
  fireImmediately: false, // Wait for proper initialization
);
```

**Why this pattern matters**: Using `fireImmediately: true` would cause the listener to execute immediately with potentially empty session data, before `SessionNotifier.init()` completes. This can result in subscriptions being created with incorrect filters, causing UI inconsistencies like missing orders in "My Trades" screen.

#### **Sequential Async Initialization**
```dart
// Proper async sequence in appInitializerProvider
await nostrService.init(settings);     // Must complete first
await keyManager.init();               // Can run after NostrService
await sessionManager.init();           // Requires KeyManager
ref.read(subscriptionManagerProvider); // Requires SessionNotifier
```

### Subscription Creation Process

The SubscriptionManager follows a standardized pattern for creating event subscriptions:

```dart
void _updateAllSubscriptions(List<Session> sessions) {
  if (sessions.isEmpty) {
    _clearAllSubscriptions();
    return;
  }

  for (final type in SubscriptionType.values) {
    _updateSubscription(type, sessions);
  }
}
```

This pattern ensures subscriptions are only created when valid session data is available.

### Filter Creation for Private Sessions

```dart
NostrFilter? _createFilterForType(SubscriptionType type, List<Session> sessions) {
  switch (type) {
    case SubscriptionType.orders:
      return NostrFilter(
        kinds: [1059], // Private gift-wrapped messages for active trading sessions
        p: sessions.map((s) => s.tradeKey.public).toList(), // Messages to my trade keys
      );
    case SubscriptionType.chat:
      return NostrFilter(
        kinds: [1059], // Private gift-wrapped chat messages
        p: sessions
            .where((s) => s.sharedKey?.public != null)
            .map((s) => s.sharedKey!.public)
            .toList(), // Messages to my shared keys
      );
    case SubscriptionType.relayList:
      return null; // Handled separately via subscribeToMostroRelayList()
  }
}
```

---

## Dual-Channel Nostr Architecture

### Overview

The Mostro Mobile app uses a **dual-channel architecture** with two completely separate subscription systems, each handling different types of Nostr events for different purposes:

1. **Private Channel (SubscriptionManager)**: Handles encrypted user sessions
2. **Public Channel (OpenOrdersRepository + OrderNotifier)**: Handles public order discovery

### Channel 1: Private Sessions - SubscriptionManager

**Purpose**: Manages private encrypted communications for active trading sessions.

**Events Handled**:
```dart
// lib/features/subscriptions/subscription_manager.dart
case SubscriptionType.orders:
  return NostrFilter(
    kinds: [1059], // Private gift-wrapped messages
    p: sessions.map((s) => s.tradeKey.public).toList(), // To user's trade keys
  );

case SubscriptionType.chat:
  return NostrFilter(
    kinds: [1059], // Private gift-wrapped chat messages  
    p: sessions
        .where((s) => s.sharedKey?.public != null)
        .map((s) => s.sharedKey!.public)
        .toList(), // To user's shared keys
  );

// Relay synchronization
case SubscriptionType.relayList:
  return NostrFilter(
    kinds: [10002], // Relay list events
    authors: [mostroPublicKey], // From Mostro instance
  );
```

**Responsibilities**:
- ✅ **My Trades** screen data
- ✅ **Private chat** messages with trading partners
- ✅ **Session state** management and updates
- ✅ **Relay synchronization** from Mostro instances
- ✅ **Trade notifications** and status changes

**Data Flow**:
```
Trading Partner → Kind 1059 (encrypted) → SubscriptionManager → MostroService → UI Updates
```

### Channel 2: Public Orders - OpenOrdersRepository + OrderNotifier

**Purpose**: Handles public order discovery and timeout detection.

**Events Handled**:
```dart
// lib/data/repositories/open_orders_repository.dart  
final filter = NostrFilter(
  kinds: [38383], // Public Mostro order events
  since: filterTime, // Last 48 hours
  authors: [_settings.mostroPublicKey], // Only from Mostro instance
);

// lib/features/order/notifiers/order_notifier.dart
// Uses 38383 events for timeout detection by comparing public state vs local state
```

**Responsibilities**:
- ✅ **Order Book** (home screen) - all available orders
- ✅ **Order discovery** - finding orders to take
- ✅ **Timeout detection** - comparing public events vs local session state  
- ✅ **Cancellation detection** - detecting when orders are canceled
- ✅ **Market data** - public order information

**Data Flow**:
```
Mostro → Kind 38383 (public) → OpenOrdersRepository → Order Book UI
Mostro → Kind 38383 (public) → OrderNotifier → Timeout Detection
```

### Architectural Separation: Dynamic vs Static Subscriptions

The real architectural principle behind this separation is **subscription lifecycle management**, not privacy levels.

#### **Dynamic Subscriptions (SubscriptionManager)**
**Principle**: Subscriptions that change based on user context

```dart
// These subscriptions RECONFIGURE when context changes
Kind 1059 (Orders): p: [myActiveTradeKeys]     // Updates with active sessions
Kind 10002 (RelayList): authors: [currentMostro]  // Updates with Mostro instance
```

**Characteristics**:
- ✅ **Context-dependent**: Change when user sessions or settings change
- ✅ **Dynamic reconfiguration**: Uses `_updateAllSubscriptions()` logic
- ✅ **Shared lifecycle**: Both require same subscribe/unsubscribe patterns
- ✅ **State listeners**: React to `sessionNotifierProvider` and `settingsProvider`

**Why Kind 10002 is here**: Relay lists need the **same dynamic reconfiguration logic** as session-based subscriptions, not because they're "private".

#### **Static Subscriptions (OpenOrdersRepository)**
**Principle**: Subscriptions that remain constant during app lifecycle

```dart
// This subscription is CONSTANT throughout app session
Kind 38383: authors: [mostroInstance] // Always same filter, independent of user context
```

**Characteristics**:
- ✅ **Context-independent**: Not affected by user's trading sessions
- ✅ **Static configuration**: Initialize once at startup
- ✅ **Global platform data**: Market information for all users
- ✅ **Simple lifecycle**: No dynamic updates needed

#### **Separation by Functional Domain**

| **Aspect** | **SubscriptionManager (Dynamic)** | **OpenOrdersRepository (Static)** |
|------------|-----------------------------------|-----------------------------------|
| **Update Trigger** | Session/Settings changes | App startup only |
| **Reconfiguration** | Frequent, context-based | None after initialization |
| **State Dependency** | Depends on user context | Independent of user state |
| **Complexity** | High (dynamic management) | Low (simple subscription) |
| **Purpose** | "Events that change with user context" | "Global platform data" |

#### **Why This Architecture Works**

1. **State Management**: Different update patterns require different architectures
2. **Performance**: Static subscriptions avoid unnecessary reconnections  
3. **Complexity Isolation**: Dynamic logic separated from simple global subscriptions
4. **Maintainability**: Clear separation of concerns by update frequency
5. **Shared Logic Reuse**: Kind 1059 and 10002 share the same reconfiguration system

#### **Legacy Benefits (Still Valid)**
- **Security**: Private events encrypted, public events accessible
- **Performance**: Focused subscriptions reduce network overhead
- **Scalability**: Independent scaling of personal vs market data
- **Fault Tolerance**: Failure isolation between systems

### Key Architectural Points

#### **SubscriptionManager Does NOT Handle Kind 38383**
```dart
// NEVER in SubscriptionManager - it only handles private events
❌ kinds: [38383] // This would be wrong - public events not handled here
✅ kinds: [1059]  // Correct - only private encrypted events
```

#### **Public Events Handled Separately**
```dart
// OpenOrdersRepository handles all 38383 events
✅ kinds: [38383] // Public order announcements from Mostro
✅ authors: [mostroPublicKey] // Only from configured Mostro instance
✅ since: filterTime // Recent orders only
```

#### **Different Filtering Strategies**
```dart
// Private events: Filter by recipient (who can decrypt)
p: [myTradeKeys] // Only messages I can decrypt

// Public events: Filter by author and time  
authors: [mostroPublicKey] // Only from Mostro
since: filterTime // Recent orders only
```

---

## Related Systems

### 1. MostroService Integration

**Purpose**: Processes private encrypted messages (Kind 1059) from active trading sessions.

**Integration**:
```dart
// lib/services/mostro_service.dart:27
_ordersSubscription = ref.read(subscriptionManagerProvider).orders.listen(
  _onData,
  onError: (error, stackTrace) {
    _logger.e('Error in orders subscription', error: error, stackTrace: stackTrace);
  },
  cancelOnError: false,
);
```

**What MostroService Actually Processes**:
```dart
Future<void> _onData(NostrEvent event) async {
  // 1. Event deduplication
  if (await eventStore.hasItem(event.id!)) return;
  
  // 2. Find matching session by trade key
  final matchingSession = sessions.firstWhereOrNull(
    (s) => s.tradeKey.public == event.recipient,
  );
  
  // 3. Decrypt NIP-59 gift-wrapped message
  final decryptedEvent = await event.unWrap(privateKey);
  
  // 4. Parse Mostro protocol message
  final msg = MostroMessage.fromJson(result[0]);
  
  // 5. Store in local database
  await messageStorage.addMessage(decryptedEvent.id!, msg);
}
```

**Impact of Fix**: ✅ **Positive** - MostroService now receives private encrypted events (Kind 1059) from properly initialized subscriptions, NOT public events (Kind 38383).

### 2. Relay Synchronization System

**Purpose**: Automatically syncs relay lists from Mostro instances.

**Integration**:
```dart
// lib/features/relays/relays_notifier.dart:488
_subscriptionManager?.subscribeToMostroRelayList(mostroPubkey);
```

**Impact of Fix**: ✅ **No Impact** - Relay sync uses separate subscription methods.

### 3. Public Order Systems (Separate from SubscriptionManager)

**Purpose**: Handle public order discovery and timeout detection using Kind 38383 events.

#### **3.1 OpenOrdersRepository**
```dart
// lib/data/repositories/open_orders_repository.dart
final filter = NostrFilter(
  kinds: [38383], // Public Mostro order events
  since: filterTime, // Last 48 hours
  authors: [_settings.mostroPublicKey], // Only from Mostro instance
);
```

**Integration**:
```dart
// lib/shared/providers/order_repository_provider.dart
final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.read(orderRepositoryProvider);
  return orderRepository.eventsStream; // Streams public 38383 events
});
```

**Powers**: Order Book (home screen), market discovery, order taking

#### **3.2 OrderNotifier Timeout Detection**
```dart
// lib/features/order/notifiers/order_notifier.dart
// Compares public 38383 events vs local session state to detect:
// - Order timeouts (waitingPayment → pending)
// - Order cancellations (active → canceled)
// - State synchronization between public announcements and private sessions
```

**Impact of Fix**: ✅ **No Impact** - Public order systems operate independently of SubscriptionManager initialization.

### 4. Chat System

**Purpose**: Handles encrypted peer-to-peer messaging via Kind 1059 events.

**Integration**: Uses SubscriptionManager chat stream for private messages between trading partners.

**Impact of Fix**: ✅ **Positive** - Chat messages now properly initialized with session data.

---

## Testing the Initialization Process

### Cold Start Testing

Testing the complete app initialization from a clean state:

```bash
# Clean app state and dependencies
flutter clean
flutter pub get
dart run build_runner build -d

# Test cold start
flutter run --release
```

**Key verification points**:
- All components initialize without errors
- UI is fully responsive after initialization
- No race conditions or timing issues occur

### Dependency Verification

Verifying proper component initialization order:

```dart
// Monitor initialization sequence in logs
NostrService → KeyManager → SessionNotifier → SubscriptionManager → Background Services
```

**Log patterns to verify**:
- `NostrService initialized successfully with X relays`
- `KeyManager: Master keys loaded from secure storage`
- `SessionNotifier: Loaded X sessions from storage`
- `Subscription created for SubscriptionType.orders with X sessions`

### Component Integration Testing

Verify that systems integrate correctly:

- **Session Restoration**: Active sessions load properly after app restart
- **Subscription Setup**: Event subscriptions match loaded sessions
- **Background Services**: Notifications and sync services activate correctly
- **Relay Connectivity**: All configured relays establish connections

### Performance Impact (Estimated)

⚠️ **Note**: These are rough estimates based on typical Flutter operations. Actual performance varies significantly based on network conditions, device performance, UI complexity, and relay responsiveness.

**Before Fix** (Estimated):
- Initial subscription creation: ~10-50ms (network dependent)
- Subscription recreation after SessionNotifier.init(): ~20-100ms (includes UI re-render overhead)
- Total: ~30-150ms + UI flickering

**After Fix** (Estimated):
- Single subscription creation: ~10-50ms (network dependent)  
- No recreation needed: Eliminates secondary overhead
- Total: ~10-50ms + no UI flickering

**Result**: ✅ **Eliminates UI flickering** + reduces initialization complexity. The exact performance gain varies by environment, but the architectural improvement is consistent.

---

## Development Guidelines

### Extending the Initialization Process

When adding new components to the app initialization sequence:

1. **Identify Dependencies**: Determine which existing systems your component requires
2. **Placement in Sequence**: Add initialization calls in the correct order within `appInitializerProvider`
3. **Async Patterns**: Use `await` for components that other systems depend on
4. **Error Handling**: Implement proper error handling and recovery mechanisms

```dart
// Example: Adding a new component
final appInitializerProvider = FutureProvider<void>((ref) async {
  // ... existing initialization ...
  
  // Add new component after its dependencies
  final newComponent = ref.read(newComponentProvider);
  await newComponent.init(); // If other systems depend on this
  
  // Or without await if independent
  ref.read(independentComponentProvider);
});
```

### Provider Dependencies Best Practices

- **Listen Pattern**: Use `fireImmediately: false` when depending on other providers
- **Explicit Dependencies**: Clearly document what each provider requires
- **State Validation**: Check that dependencies are initialized before using them
- **Error Propagation**: Handle dependency initialization failures gracefully

### Architecture Evolution

#### **Scaling Considerations**
- Monitor initialization time as components are added
- Consider parallel initialization for independent systems
- Implement lazy loading for non-critical components
- Use dependency injection patterns to manage complexity

#### **Performance Optimization**
- Profile initialization performance regularly
- Identify bottlenecks in the startup sequence  
- Consider background initialization for heavy operations
- Implement progressive enhancement patterns

#### **Monitoring and Observability**
- Maintain comprehensive logging throughout initialization
- Add performance metrics for each initialization phase
- Implement health checks for critical components
- Use tracing to understand initialization flow in production

---

## Conclusion

The Mostro Mobile app initialization process represents a sophisticated bootstrap sequence that ensures all critical systems are properly configured before user interaction begins. This comprehensive initialization flow demonstrates several key architectural principles:

### **Core Design Principles**

#### **Dependency Management**
- **Sequential Initialization**: Critical components initialize in dependency order
- **Proper Timing**: `fireImmediately: false` patterns prevent race conditions
- **Error Handling**: Graceful failure handling at each initialization stage

#### **Dual-Channel Architecture**
- **Dynamic Subscriptions**: SubscriptionManager handles context-dependent events (Kind 1059, 10002)
- **Static Subscriptions**: OpenOrdersRepository manages global platform data (Kind 38383)  
- **Separation of Concerns**: Clear boundaries between private trading data and public market information

#### **Extensible Design**
- **Clear Patterns**: Well-defined approaches for adding new components
- **Provider Integration**: Consistent use of Riverpod for dependency injection
- **Scalable Structure**: Architecture supports growth without major refactoring

### **Key Takeaways for Developers**

1. **Initialization Order Matters**: Carefully consider dependencies when adding new components
2. **Timing Patterns**: Use appropriate `fireImmediately` settings based on dependency requirements
3. **Architecture Separation**: Maintain clear boundaries between different data channels and responsibilities
4. **Documentation Value**: Technical documentation must accurately reflect implementation details

This initialization system provides a robust foundation for the app's trading operations while maintaining clear architectural boundaries and extensible patterns for future development.

---
**Last Updated**: 2025-08-28  