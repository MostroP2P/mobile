# Mostro Mobile - Architecture Overview

## Executive Summary

Mostro Mobile is a sophisticated peer-to-peer Bitcoin trading application built on Flutter that leverages the Nostr protocol for decentralized, censorship-resistant trading. This document provides a comprehensive architectural overview of the application's structure, patterns, and core systems.

**Key Architectural Principles:**
- **Decentralized Architecture**: Built on Nostr protocol with no central points of failure
- **Feature-Based Organization**: Clear separation of concerns using feature modules
- **Reactive State Management**: Riverpod-based reactive architecture
- **Privacy-First Design**: End-to-end encryption and hierarchical key management
- **Account Recovery**: BIP-39 mnemonic-based complete state restoration
- **Real-Time Synchronization**: Live updates via WebSocket subscriptions
- **Multi-Platform Support**: Single codebase for Android and iOS

---

## Project Structure Overview

### High-Level Directory Organization
```
lib/
├── core/                    # Central configuration and FSM
│   ├── app.dart            # Main application configuration
│   ├── app_routes.dart     # Navigation routing
│   ├── app_theme.dart      # UI theming
│   ├── config.dart         # Global configuration
│   ├── mostro_fsm.dart     # Order state machine
│   └── models/             # Core models (relay events, etc.)
├── features/               # Feature-based organization
│   ├── auth/              # Authentication and registration
│   ├── chat/              # Peer-to-peer messaging
│   ├── home/              # Order book and dashboard
│   ├── key_manager/       # Cryptographic key management
│   ├── mostro/            # Mostro protocol integration
│   ├── order/             # Order creation and management
│   ├── rate/              # Rating and reputation system
│   ├── relays/            # Relay management and synchronization
│   ├── restore/           # Account recovery from mnemonic
│   ├── settings/          # User preferences and configuration
│   ├── subscriptions/     # Event subscription management
│   ├── trades/            # Active trade management
│   └── walkthrough/       # User onboarding
├── shared/                # Shared utilities and components
│   ├── notifiers/         # Shared state notifiers
│   ├── providers/         # Shared Riverpod providers
│   ├── utils/             # Utility functions
│   └── widgets/           # Reusable UI components
├── data/                  # Data layer
│   ├── models/            # Data models and enums
│   └── repositories/      # Repository pattern implementations
├── services/              # Core services
│   ├── nostr_service.dart      # Nostr protocol integration
│   ├── mostro_service.dart     # Mostro trading protocol
│   ├── event_bus.dart          # Inter-service communication
│   ├── exchange_service.dart   # Fiat/Bitcoin exchange rates
│   └── lifecycle_manager.dart  # Application lifecycle
├── background/            # Background services
│   ├── abstract_background_service.dart
│   ├── mobile_background_service.dart
│   └── desktop_background_service.dart
├── notifications/         # Local notifications
├── l10n/                  # Internationalization
│   ├── intl_en.arb       # English translations
│   ├── intl_es.arb       # Spanish translations
│   └── intl_it.arb       # Italian translations
└── generated/             # Generated files (DO NOT EDIT)
```

### Feature Module Structure
Each feature follows a consistent internal organization:
```
features/{feature}/
├── screens/              # UI screens for the feature
├── providers/            # Riverpod providers
├── notifiers/            # Complex state management
├── widgets/              # Feature-specific widgets
└── models/               # Feature-specific models (if needed)
```

---

## Core Systems Architecture

### 🚀 Application Initialization System
The app follows a precise initialization sequence to ensure proper dependency order and system readiness.

**📚 Detailed Documentation**: [`APP_INITIALIZATION_ANALYSIS.md`](APP_INITIALIZATION_ANALYSIS.md)

**Key Components:**
- **AppInitProvider**: Orchestrates the complete startup sequence
- **NostrService**: Establishes relay connections before other services
- **KeyManager**: Loads cryptographic keys from secure storage
- **SessionNotifier**: Restores active trading sessions
- **SubscriptionManager**: Sets up event subscriptions with `fireImmediately: false`

**Critical Dependencies:**
```
NostrService → KeyManager → SessionNotifier → SubscriptionManager → Background Services
```

### 🔗 Relay Synchronization System
Sophisticated automatic relay management that synchronizes with Mostro instances while preserving user control.

**📚 Detailed Documentation**: [`RELAY_SYNC_IMPLEMENTATION.md`](RELAY_SYNC_IMPLEMENTATION.md)

**Key Features:**
- **Automatic Discovery**: NIP-65 relay list events (kind 10002) from Mostro instances
- **Dual Storage Strategy**: Active URLs separate from metadata preservation
- **Intelligent Blacklisting**: Non-destructive relay blocking with restoration
- **Two-Tier Validation**: Nostr protocol + WebSocket connectivity testing
- **Source Classification**: User, Mostro, and default relay categorization

**Core Components:**
- **RelaysNotifier**: Central relay management orchestration (864 lines)
- **RelayListEvent**: NIP-65 event parser and validator
- **SubscriptionManager**: Real-time relay list subscription handling

### ⏱️ Timeout Detection & Session Management
Real-time system that detects order timeouts and handles maker/taker scenarios differently.

**📚 Detailed Documentation**: [`TIMEOUT_DETECTION_AND_SESSION_CLEANUP.md`](TIMEOUT_DETECTION_AND_SESSION_CLEANUP.md)

**Detection Mechanism:**
- **Real-time Monitoring**: 38383 public events for status changes
- **Smart Logic**: `public=pending + local=waiting = guaranteed timeout`
- **Differentiated Handling**: Maker sessions preserved, taker sessions deleted
- **Cancellation Detection**: State-based cleanup for canceled orders

**Race Protection:**
- **`_isProcessingTimeout` flag**: Prevents concurrent execution
- **Early return handling**: Proper flow control
- **Error resilience**: Comprehensive exception handling

### 🔐 Nostr Protocol Integration
Comprehensive implementation of Nostr protocol with advanced privacy features.

**📚 Detailed Documentation**: [`NOSTR.md`](NOSTR.md)

**Protocol Features:**
- **NIP-01**: Basic protocol flow and event structure
- **NIP-06**: BIP-32 key derivation from mnemonic seeds
- **NIP-44**: Versioned encryption for secure communications
- **NIP-59**: Three-layer gift wrapping for metadata protection
- **NIP-65**: Relay list management for automatic discovery
- **NIP-69**: Public order events for market discovery

**Key Management:**
- **Hierarchical Derivation**: BIP-32 compliant key derivation
- **Trade-Specific Keys**: Unique keys per trading session
- **Secure Storage**: Hardware-backed secure storage for private keys
- **Key Rotation**: Automatic privacy-preserving key rotation

### 🔄 Account Recovery System
Complete account restoration from 12-word mnemonic seed phrases with full state reconstruction.

**📚 Detailed Documentation**: [`SESSION_RECOVERY_ARCHITECTURE.md`](SESSION_RECOVERY_ARCHITECTURE.md)

**Recovery Capabilities:**
- **Cryptographic Recovery**: Master key and trade key regeneration from mnemonic
- **Session Restoration**: Complete trading sessions recreated from Mostro backend
- **Trade Index Sync**: Precise synchronization with last used trade key index  
- **Order State Rebuild**: Full order history and dispute information recovery
- **Privacy Mode Support**: Recovery is supported in reputation mode only. Privacy mode is not supported because Mostrod cannot link order history requests to a user (this is the intended behavior)


**Multi-Stage Process:**
```
Mnemonic Import → Data Cleanup → Backend Sync → Session Recreation → State Rebuild
```

**Key Components:**
- **RestoreService**: Orchestrates the complete 4-stage recovery workflow
- **RestoreProgressNotifier**: Provides real-time recovery progress to users
- **ImportMnemonicDialog**: Secure mnemonic input with BIP-39 validation

---

## State Management Architecture

### Riverpod-Based Reactive System
The application uses Riverpod for comprehensive state management with clear separation of concerns.

#### Provider Organization
```dart
// Dependency Injection Providers
final nostrServiceProvider = Provider<NostrService>((ref) => ...);
final mostroServiceProvider = Provider<MostroService>((ref) => ...);

// State Management Providers  
final sessionNotifierProvider = StateNotifierProvider<SessionNotifier, List<Session>>(...);
final relaysNotifierProvider = StateNotifierProvider<RelaysNotifier, List<Relay>>(...);
final orderNotifierProvider = StateNotifierProvider<OrderNotifier, OrderState>(...);

// Computed State Providers
final activeOrdersProvider = Provider<List<Order>>((ref) => ...);
final availableRelaysProvider = Provider<List<Relay>>((ref) => ...);
```

#### Notifier Pattern for Complex Logic
Complex business logic is encapsulated in StateNotifier classes:
- **AuthNotifier**: Authentication and user registration
- **SessionNotifier**: Active trading session management
- **RelaysNotifier**: Relay discovery and synchronization
- **OrderNotifier**: Individual order lifecycle management
- **ChatRoomNotifier**: Peer-to-peer messaging state

### Repository Pattern Implementation
All data access goes through repository classes for clean separation:
```dart
// Abstract repository interfaces
abstract class OrderRepositoryInterface {
  Future<List<Order>> getOrders();
  Future<void> saveOrder(Order order);
  Future<void> deleteOrder(String orderId);
  Future<void> clearCache(); // Used during account recovery
}

// Concrete implementations
class OpenOrdersRepository implements OrderRepositoryInterface { ... }
class MostroStorage implements BaseStorage { ... }
class EventStorage implements BaseStorage { ... }
```

---

## Data Layer Architecture

### Sembast NoSQL Database Strategy
The application uses Sembast for local data persistence with a dual-database approach:

#### Database Organization
- **`mostro.db`**: Trading data, sessions, messages, and chat history
- **`events.db`**: Nostr events, relay information, and protocol metadata

#### Storage Patterns
```dart
// Database providers
final mostroDatabase = Provider<Database>((ref) => ...);
final eventsDatabase = Provider<Database>((ref) => ...);

// Repository pattern with type-safe stores
final ordersStore = intMapStoreFactory.store('orders');
final sessionsStore = intMapStoreFactory.store('sessions'); 
final chatStore = intMapStoreFactory.store('chat_messages');
```

### Event Storage & Deduplication
Sophisticated event handling prevents duplicate processing:
- **Hash-based deduplication**: Events identified by content hash
- **Timestamp validation**: Prevents processing of outdated events
- **Source tracking**: Events tagged by relay source
- **Automatic cleanup**: Old events pruned periodically

---

## Security Architecture

### End-to-End Encryption
All trade communications use NIP-59 gift wrapping with three encryption layers:
```
┌─────────────────────────────────────────────────────────────┐
│                     Kind 1059 Event                        │
│                   (Wrapper Event)                          │
│  ┌───────────────────────────────────────────────────────┐  │
│  │               Kind 13 Event                           │  │
│  │                (Seal Event)                           │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │             Kind 1 Event                        │  │  │
│  │  │              (Rumor Event)                      │  │  │
│  │  │  - Original message content                     │  │  │
│  │  │  - Trade data and order information             │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  Encrypted: Sender Trade Key → Recipient Trade Key     │  │
│  └───────────────────────────────────────────────────────┘  │
│  Encrypted: Ephemeral Key → Recipient Trade Key            │
└─────────────────────────────────────────────────────────────┘
```

### Key Management Security
- **BIP-39 Mnemonic**: 12-word recovery phrases for complete account backup
- **BIP-32 Derivation**: Hierarchical deterministic key derivation
- **Trade-Specific Keys**: Unique keys per trade prevent transaction linking
- **Account Recovery**: Complete state restoration from mnemonic seed phrase
- **Secure Storage**: Platform-native secure storage for private keys
- **Memory Protection**: Secure clearing of sensitive data from memory

---

## Background Services & Notifications

### Platform-Specific Background Services
- **Mobile**: `MobileBackgroundService` for persistent operation
- **Desktop**: `DesktopBackgroundService` for desktop platforms
- **Abstract Interface**: Common interface ensures consistent behavior

### Notification System
- **Local Notifications**: Real-time trade updates and status changes
- **Permission Handling**: Runtime permission requests and management
- **Custom Icons**: Enhanced notification visibility with custom assets
- **Background Processing**: Continues operation when app is minimized

### Lifecycle Management
- **App State Monitoring**: Tracks foreground/background state transitions
- **Resource Management**: Proper cleanup of connections and subscriptions
- **Graceful Degradation**: Maintains core functionality under resource constraints

---

## Performance Optimizations

### Connection Management
- **Connection Pooling**: Efficient WebSocket connection reuse
- **Lazy Initialization**: Connect to services only when needed
- **Resource Cleanup**: Proper cleanup prevents memory leaks

### Event Processing
- **Async Processing**: Non-blocking event processing
- **Batch Operations**: Efficient handling of multiple events
- **Smart Caching**: Frequently accessed data cached appropriately

### UI Responsiveness
- **Background Processing**: Heavy operations moved to background threads
- **Progressive Loading**: Incremental UI updates for better perceived performance
- **Reactive Updates**: Efficient UI updates only when state changes

---

## Development Principles

### Code Quality Standards
- **Zero Flutter Analyze Issues**: Maintained throughout development
- **Modern APIs**: Always use latest non-deprecated APIs
- **BuildContext Safety**: Proper `mounted` checks after async operations
- **Const Optimization**: Use `const` constructors where possible

### Architectural Patterns
- **Feature-Based Organization**: Clear separation of concerns
- **Repository Pattern**: All data access through repositories
- **Provider Pattern**: Dependency injection via Riverpod
- **Notifier Pattern**: Complex state logic encapsulated in StateNotifiers

### Testing Strategy
- **Unit Tests**: Core business logic and utility functions
- **Integration Tests**: End-to-end trading workflows
- **Mock Strategy**: Comprehensive Riverpod provider mocking
- **Generated Files**: Mockito-generated mocks with proper cleanup

---

## Internationalization (i18n)

### Multi-Language Support
Complete localization for three languages:
- **English (en)**: Base language with comprehensive coverage
- **Spanish (es)**: Full translation with cultural considerations
- **Italian (it)**: Complete localization including time formatting

### Localization Architecture
```dart
// ARB file structure
lib/l10n/
├── intl_en.arb     # English (base language)
├── intl_es.arb     # Spanish translations  
└── intl_it.arb     # Italian translations

// Generated localization classes
lib/generated/
├── l10n.dart       # Main localization class
├── l10n_en.dart    # English implementation
├── l10n_es.dart    # Spanish implementation
└── l10n_it.dart    # Italian implementation
```

### Advanced i18n Features
- **Time Localization**: Locale-aware time formatting ("hace X horas" vs "X hours ago")
- **Currency Formatting**: Regional currency display preferences
- **Parameterized Strings**: Type-safe parameter handling with metadata
- **Pluralization**: Proper plural forms for different languages

---

## Error Handling & Resilience

### Network Resilience
- **Retry Logic**: Exponential backoff for failed operations
- **Fallback Mechanisms**: Alternative relays when primary fails
- **Timeout Handling**: Appropriate timeouts for different operations
- **Connection Health**: Real-time monitoring and automatic recovery

### State Management Resilience  
- **State Validation**: Multiple validation layers prevent invalid states
- **Rollback Capabilities**: Failed operations don't corrupt existing state
- **Race Condition Protection**: Proper synchronization prevents conflicts
- **Error Boundaries**: Isolated error handling prevents cascading failures

### User Experience Resilience
- **Graceful Degradation**: Core functionality maintained under adverse conditions
- **User Feedback**: Clear error messages and recovery suggestions
- **Offline Capability**: Essential functions work without network connectivity
- **Data Recovery**: Automatic recovery from corrupted or missing data

---

## Development Workflow

### Essential Commands
```bash
# Development
flutter pub get                    # Install dependencies
flutter run                       # Run application
dart run build_runner build -d    # Generate code and mocks
flutter gen-l10n                  # Generate localization files

# Quality Assurance  
flutter analyze                   # Static code analysis (MUST be zero issues)
flutter test                      # Unit tests
flutter test integration_test/    # Integration tests
flutter format .                  # Code formatting
```

### Code Generation
The project uses extensive code generation:
- **Riverpod Providers**: Auto-generated provider code
- **Mockito Mocks**: Test mocking infrastructure
- **Localization**: i18n string classes
- **JSON Serialization**: Model serialization code

### Git Workflow
- **Feature Branches**: Use descriptive branch names (`feat/feature-name`)
- **Commit Messages**: Follow conventional commit format
- **Pull Requests**: All changes go through code review
- **CI/CD**: Automated testing and quality checks

---

## Architecture Decision Records

### Why Nostr Protocol?
- **Decentralization**: No central points of failure
- **Censorship Resistance**: Cannot be shut down by authorities
- **Privacy**: End-to-end encryption built into protocol
- **Extensibility**: Protocol designed for custom applications

### Why Flutter?
- **Cross-Platform**: Single codebase for Android and iOS
- **Performance**: Near-native performance with excellent UX
- **Ecosystem**: Rich ecosystem of packages and tools
- **Developer Experience**: Hot reload and comprehensive tooling

### Why Riverpod for State Management?
- **Type Safety**: Compile-time provider dependency validation
- **Performance**: Granular reactivity and efficient rebuilds
- **Testing**: Excellent provider override capabilities
- **Architecture**: Promotes clean separation of concerns

### Why Sembast for Local Storage?
- **NoSQL Flexibility**: Schema-less design suits dynamic trading data
- **Performance**: Fast read/write operations for mobile devices
- **Dart Native**: Written in Dart, no platform bridge overhead
- **Transactions**: ACID compliance for data integrity

---

## File Organization Reference

### Critical Configuration Files
```
# Core Configuration
lib/core/config.dart                 # Global app configuration
lib/core/app_routes.dart            # Navigation routing
lib/core/mostro_fsm.dart           # Order state machine

# Service Layer
lib/services/nostr_service.dart     # Nostr protocol integration
lib/services/mostro_service.dart    # Mostro trading protocol
lib/services/event_bus.dart         # Inter-service communication

# Key Management & Recovery
lib/features/key_manager/key_manager.dart        # Cryptographic operations
lib/features/key_manager/key_storage.dart        # Secure key storage  
lib/features/key_manager/key_derivator.dart      # BIP-32 key derivation
lib/features/restore/restore_manager.dart        # Account recovery orchestration
lib/features/restore/restore_progress_notifier.dart # Recovery progress state

# Data Layer
lib/data/repositories/              # Repository implementations
lib/shared/providers/               # Shared Riverpod providers
```

### Generated Files (Never Edit Manually)
```
lib/generated/                      # Localization classes
*.g.dart                           # Generated Riverpod code
*.mocks.dart                       # Generated Mockito mocks
test/mocks.mocks.dart              # Main test mocking file
```

---

## External Dependencies

### Core Framework
- **Flutter SDK**: Cross-platform UI framework
- **Dart SDK**: Programming language and runtime

### State Management & Architecture
- **flutter_riverpod**: Reactive state management
- **riverpod**: Core state management library
- **go_router**: Declarative routing

### Nostr Protocol & Cryptography
- **dart_nostr**: Core Nostr protocol implementation
- **crypto**: Cryptographic operations
- **bip32**: Hierarchical deterministic key derivation  
- **bip39**: Mnemonic seed phrase generation and account recovery

### Data & Storage
- **sembast**: NoSQL database for local storage
- **flutter_secure_storage**: Secure storage for cryptographic keys
- **shared_preferences**: User preferences and settings

### UI & Internationalization  
- **flutter_localizations**: Internationalization support
- **intl**: Date, number, and message formatting
- **timeago**: Relative time formatting

### Background & Notifications
- **flutter_background_service**: Background processing
- **flutter_local_notifications**: Local notification system
- **permission_handler**: Runtime permission management

### Development & Testing
- **build_runner**: Code generation orchestration
- **mockito**: Test mocking framework
- **flutter_test**: Testing framework
- **integration_test**: End-to-end testing

---

## Security Considerations

### Cryptographic Security
- **Key Generation**: Cryptographically secure random number generation
- **Key Storage**: Hardware-backed secure storage where available
- **Key Derivation**: Industry-standard BIP-32/BIP-39 implementation
- **Encryption**: ChaCha20-Poly1305 with proper nonce handling

### Network Security
- **TLS/WebSocket Security**: All connections use secure protocols
- **Certificate Validation**: Proper certificate chain validation
- **Relay Validation**: Domain-based relay validation prevents IP attacks
- **Input Sanitization**: All user inputs properly validated

### Application Security
- **Code Obfuscation**: Production builds use code obfuscation
- **Debug Protection**: Debug features disabled in production builds
- **Memory Protection**: Sensitive data cleared from memory after use
- **Secure Storage**: Platform-native secure storage for sensitive data

---

## Performance Monitoring

### Key Metrics
- **App Launch Time**: Target sub-3 second cold start
- **Memory Usage**: Monitor for memory leaks and excessive consumption
- **Network Performance**: Relay connection health and message latency
- **UI Responsiveness**: 60fps target with jank monitoring

### Optimization Strategies
- **Lazy Loading**: Load data and UI components on demand
- **Connection Pooling**: Reuse WebSocket connections efficiently
- **Caching**: Smart caching of frequently accessed data
- **Background Processing**: Move heavy operations off main thread

---

## Future Architecture Considerations

### Scalability Enhancements
- **Horizontal Scaling**: Support for additional Mostro instances
- **Performance Optimization**: Further mobile-specific optimizations
- **Feature Modularity**: Enhanced plugin architecture for new features
- **Recovery Improvements**: Enhanced dispute detection and cloud backup options

### Protocol Extensions
- **Lightning Integration**: Direct Lightning Network integration
- **Multi-signature Support**: Enhanced security through multi-sig escrow
- **Advanced Privacy**: Additional privacy-preserving features

### Platform Expansion
- **Web Support**: PWA version for browser-based trading
- **Desktop Optimization**: Enhanced desktop-specific features
- **API Integration**: RESTful API for third-party integrations

---
 
**Last Updated**: November 25, 2025
**Related Documentation**: 
- [Session Recovery Architecture](SESSION_RECOVERY_ARCHITECTURE.md)
- [Session and Key Management](SESSION_AND_KEY_MANAGEMENT.md)
- [Nostr Integration](NOSTR.md)

*This architecture documentation is a living document that evolves with the codebase. All architectural decisions should be reflected here, and any significant changes should be documented with rationale and impact analysis.*