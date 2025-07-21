# Nostr Integration in Mostro Mobile

This document provides comprehensive technical documentation for how the Mostro Mobile app integrates with the Nostr protocol to enable peer-to-peer Bitcoin trading.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Key Management & Security](#key-management--security)
- [Relay Management](#relay-management)
- [Message Flow & Communication](#message-flow--communication)
- [Mostro Protocol Implementation](#mostro-protocol-implementation)
- [NIP Compliance](#nip-compliance)
- [Technical Implementation Details](#technical-implementation-details)

## Overview

The Mostro Mobile app is built on top of the Nostr protocol to provide a decentralized, censorship-resistant platform for peer-to-peer Bitcoin trading. The app implements a sophisticated integration that leverages multiple Nostr Improvement Proposals (NIPs) to ensure privacy, security, and reliability.

### Core Principles

- **Decentralization**: No central authority controls the trading platform
- **Privacy**: Advanced encryption ensures trade communications remain private
- **Censorship Resistance**: Multiple relay support prevents single points of failure
- **Key Rotation**: Unique keys for each trade prevent transaction linking
- **End-to-End Encryption**: All trade communications use NIP-59 gift wrapping

## Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Mostro Mobile App                        │
├─────────────────────────────────────────────────────────────┤
│  UI Layer (Flutter)                                        │
│  ├── Settings/Account Screens                              │
│  ├── Order Management                                      │
│  ├── Chat Interface                                        │
│  └── Relay Configuration                                   │
├─────────────────────────────────────────────────────────────┤
│  Business Logic (Riverpod)                                 │
│  ├── MostroService (Protocol Implementation)               │
│  ├── NostrService (Core Nostr Integration)                 │
│  ├── KeyManager (Cryptographic Operations)                 │
│  └── Session Management                                    │
├─────────────────────────────────────────────────────────────┤
│  Data Layer                                                │
│  ├── Sembast Database (Local Storage)                      │
│  ├── Flutter Secure Storage (Keys)                         │
│  └── Repository Pattern                                    │
├─────────────────────────────────────────────────────────────┤
│  Nostr Integration (dart_nostr)                            │
│  ├── WebSocket Connections                                 │
│  ├── Event Publishing/Subscription                         │
│  ├── Cryptographic Operations                              │
│  └── NIP Implementations                                   │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Nostr Network                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Relay 1   │  │   Relay 2   │  │   Relay N   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Core Services

#### NostrService (`lib/services/nostr_service.dart`)
The foundational service that manages all Nostr protocol interactions:

- **Relay Management**: Maintains WebSocket connections to multiple relays
- **Event Publishing**: Publishes events to all configured relays with retry logic
- **Event Subscription**: Creates filtered subscriptions for real-time updates
- **NIP-59 Implementation**: Complete gift wrapping for private messaging
- **Connection Health**: Monitors relay connectivity and implements failover

#### MostroService (`lib/services/mostro_service.dart`)
Implements the Mostro protocol specifics on top of Nostr:

- **Session Management**: Tracks active trading sessions
- **Message Processing**: Handles incoming Mostro protocol messages
- **Order Lifecycle**: Manages complete trade flow from creation to completion
- **Automatic Recovery**: Re-establishes subscriptions on app restart

## Key Management & Security

### Hierarchical Deterministic (HD) Key Derivation

The app implements a sophisticated key management system following BIP-32 and NIP-06 standards:

#### Master Key Generation
```
BIP-39 Mnemonic (12/24 words)
        ↓
BIP-32 Seed (512 bits)
        ↓
Master Extended Private Key
        ↓
Derivation Path: m/44'/1237'/0'/0/trade_index
        ↓
Trade-Specific Key Pair
```

#### Key Storage Architecture
- **Master Key**: Stored in Flutter Secure Storage, encrypted at rest
- **Trade Keys**: Derived on-demand, never persisted in plain text
- **Mnemonic Backup**: User's recovery phrase, encrypted and stored securely
- **Key Indices**: Track current trade key index for rotation

#### Privacy Features
- **Unique Trade Keys**: Each trading session uses a different key pair
- **Key Rotation**: Automatic increment of key indices prevents linking
- **Full Privacy Mode**: Option to disable reputation tracking for maximum anonymity
- **Secure Deletion**: Keys are properly cleared from memory after use

### Cryptographic Operations

#### Key Derivation Process
```dart
// Generate master key from mnemonic
final seed = mnemonicToSeed(mnemonic);
final masterKey = ExtendedPrivateKey.master(seed);

// Derive trade-specific key
final derivationPath = "m/44'/1237'/0'/0/$tradeIndex";
final tradeKey = masterKey.derivePath(derivationPath);

// Extract key pair for Nostr operations
final privateKey = tradeKey.key;
final publicKey = privateKey.publicKey;
```

#### Security Measures
- **Secure Random**: Cryptographically secure random number generation
- **Key Validation**: Comprehensive validation of all cryptographic inputs
- **Memory Management**: Secure clearing of sensitive data from memory
- **Hardware Security**: Leverages platform secure storage mechanisms

## Relay Management

### Configuration and Connectivity

#### Default Relay Configuration
```dart
static const List<String> nostrRelays = [
  'wss://relay.mostro.network',
  // Additional relays can be configured by users
];
```

#### Dynamic Relay Management
Users can configure custom relays through the app interface:

- **Add/Remove Relays**: Dynamic relay list management
- **Health Monitoring**: Real-time connectivity status
- **Performance Metrics**: Connection latency and reliability tracking
- **Failover Logic**: Automatic switching when relays become unavailable

#### Connection Management
```dart
// Initialize connections to all configured relays
await nostrService.init(relays);

// Publish event to all relays with error handling
await nostrService.publishEvent(event);

// Subscribe with automatic relay selection
final subscription = await nostrService.subscribeToEvents(filters);
```

### Reliability Features

#### Multi-Relay Publishing
- **Redundancy**: Events published to all available relays
- **Parallel Processing**: Simultaneous publishing for faster propagation
- **Error Tolerance**: Continues operation even if some relays fail
- **Retry Logic**: Automatic retry with exponential backoff

#### Connection Health
- **Heartbeat Monitoring**: Regular connectivity checks
- **Automatic Reconnection**: Seamless reconnection on network changes
- **Timeout Handling**: Configurable timeouts for different operations
- **Status Reporting**: Real-time relay status in the UI

## Message Flow & Communication

### NIP-59 Gift Wrapping Implementation

The app implements a three-layer encryption system for all private communications:

#### Layer Structure
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
│  │  │  - Trade data                                   │  │  │
│  │  │  - Order information                            │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  Encrypted with: Sender Trade Key → Recipient Trade Key │
│  └───────────────────────────────────────────────────────┘  │
│  Encrypted with: Ephemeral Key → Recipient Trade Key        │
└─────────────────────────────────────────────────────────────┘
```

#### Encryption Process
1. **Create Rumor** (Kind 1): Original message content
2. **Create Seal** (Kind 13): Encrypt rumor with sender's trade key
3. **Create Wrapper** (Kind 1059): Final encryption with ephemeral key

#### Decryption Process
1. **Unwrap** the outer Kind 1059 event
2. **Unseal** the inner Kind 13 event
3. **Extract** the original Kind 1 rumor content

### Message Types and Routing

#### Mostro Protocol Messages (Kind 1059)
- **Order Operations**: Take, cancel, release, dispute
- **Trade Communications**: Status updates, confirmations
- **Invoice Handling**: Lightning invoice exchange
- **Dispute Resolution**: Mediation and arbitration

#### Public Order Events (Kind 38383 - NIP-69)
- **Order Announcements**: Public order book entries
- **Market Discovery**: Browse available trades
- **Order Metadata**: Trade parameters and requirements

#### Chat Messages (Kind 1059)
- **Peer-to-Peer**: Direct communication between traders
- **Admin Communication**: Support and dispute resolution
- **Real-time**: Live chat during active trades

### Event Filtering and Subscription

#### Filter Configuration
```dart
// Subscribe to Mostro messages for specific trade key
final filters = [
  NostrFilter(
    kinds: [1059],
    p: [tradePublicKey],
    since: lastSeenTimestamp,
  )
];

// Subscribe to public orders
final orderFilters = [
  NostrFilter(
    kinds: [38383],
    authors: [mostroPublicKey],
  )
];
```

#### Real-time Updates
- **Live Subscriptions**: Real-time message delivery
- **Offline Sync**: Catch up on missed messages when reconnecting
- **Event Deduplication**: Handle duplicate events from multiple relays
- **Chronological Ordering**: Proper message ordering across relays

## Mostro Protocol Implementation

### Finite State Machine

The app implements a comprehensive state machine for order lifecycle management:

#### Order States
```
Pending → Waiting Payment → Active → Fiat Sent → Success
    ↓                         ↓           ↓
 Canceled               Canceled    Canceled
```

#### Role-Specific State Transitions

**Buyer Flow:**
1. `pending` → `waitingBuyerInvoice` (after order taken)
2. `waitingBuyerInvoice` → `waitingPayment` (invoice submitted)
3. `waitingPayment` → `active` (payment confirmed)
4. `active` → `fiatSent` (fiat payment made)
5. `fiatSent` → `success` (seller releases Bitcoin)

**Seller Flow:**
1. `pending` → `waitingPayment` (after order taken)
2. `waitingPayment` → `waitingBuyerInvoice` (hold invoice paid)
3. `waitingBuyerInvoice` → `active` (buyer invoice received)
4. `active` → `fiatSent` (buyer sends fiat)
5. `fiatSent` → `success` (Bitcoin released)

#### Available Actions by State
```dart
// Example: Actions available in 'active' state for seller
final actions = MostroFSM.possibleActions(Status.active, Role.seller);
// Returns: [Action.fiatSent, Action.cancel, Action.dispute]
```

### Session Management

#### Trade Session Lifecycle
```dart
class Session {
  final String orderId;
  final String tradeIndex;
  final NostrKeyPairs tradeKeys;
  final String peerPublicKey;
  final String? mostroPublicKey;
  final DateTime createdAt;
  final Status status;
  final Role role;
}
```

#### Session Operations
- **Creation**: New session for each trade with unique keys
- **Persistence**: Sessions stored locally for recovery
- **Cleanup**: Automatic removal of completed sessions after 24 hours
- **Recovery**: Re-establish subscriptions on app restart

### Order Operations

#### Creating Orders
```dart
// Submit new buy order
await mostroService.submitOrder(
  orderType: OrderType.buy,
  amount: amountSats,
  fiatCode: 'USD',
  fiatAmount: 100,
  paymentMethod: 'Cash',
);
```

#### Taking Orders
```dart
// Take existing sell order
await mostroService.takeSellOrder(
  orderId: existingOrderId,
  lightningAddress: 'user@domain.com',
);
```

#### Trade Completion
```dart
// Seller releases Bitcoin to buyer
await mostroService.releaseOrder(orderId);

// Buyer confirms fiat payment sent
await mostroService.sendFiatSent(orderId);
```

### Dispute Resolution

#### Dispute Initiation
```dart
// Either party can initiate dispute
await mostroService.disputeOrder(orderId);
```

#### Admin Operations
- **Dispute Resolution**: Admin can resolve disputes
- **Cancel Orders**: Emergency order cancellation
- **User Management**: Ban/unban problematic users

## NIP Compliance

### Implemented NIPs

#### NIP-01: Basic Protocol Flow Description
- **Event Structure**: Standard Nostr event format
- **Signing**: Schnorr signatures for all events
- **Verification**: Cryptographic signature verification
- **JSON Encoding**: Proper event serialization

#### NIP-06: Basic Key Derivation From Mnemonic Seed Phrase
- **Mnemonic Generation**: BIP-39 compliant seed phrases
- **Key Derivation**: BIP-32 hierarchical deterministic derivation
- **Derivation Paths**: Configurable derivation paths for different purposes
- **Key Recovery**: Full key recovery from mnemonic backup

#### NIP-44: Versioned Encryption
- **Encryption Scheme**: ChaCha20-Poly1305 with proper nonce handling
- **Key Agreement**: ECDH key agreement protocol
- **Version Handling**: Support for encryption version upgrades
- **Padding**: Proper message padding for metadata protection

#### NIP-59: Gift Wrap
- **Three-Layer Encryption**: Rumor → Seal → Wrapper structure
- **Ephemeral Keys**: Temporary keys for wrapper layer
- **Metadata Protection**: Hides sender/recipient information
- **Forward Secrecy**: Ephemeral keys provide forward secrecy

#### NIP-69: Offer Events
- **Public Orders**: Order book events for market discovery
- **Order Metadata**: Structured order information
- **Search Filters**: Efficient order filtering and discovery
- **Market Making**: Support for liquidity provision

### Custom Extensions

#### Trade Key Management
- **Key Rotation**: Automatic key rotation for privacy
- **Privacy Modes**: Configurable privacy vs reputation trade-offs
- **Key Backup**: Secure backup and recovery mechanisms

#### Session Management
- **Trade Sessions**: Persistent session state management
- **Recovery**: Automatic session recovery on app restart
- **Cleanup**: Secure cleanup of completed sessions

## Technical Implementation Details

### Dependencies and Libraries

#### Core Nostr Integration
- **dart_nostr**: Primary Nostr protocol implementation
- **crypto**: Cryptographic operations and key management
- **websocket**: Real-time communication with relays

#### State Management
- **riverpod**: Reactive state management
- **flutter_riverpod**: Flutter integration for Riverpod

#### Local Storage
- **sembast**: NoSQL database for events and messages
- **flutter_secure_storage**: Secure storage for cryptographic keys
- **shared_preferences**: Non-sensitive configuration storage

#### Background Services
- **flutter_background_service**: Background processing
- **flutter_local_notifications**: Push notifications

### Performance Optimizations

#### Connection Management
- **Connection Pooling**: Efficient WebSocket connection reuse
- **Lazy Initialization**: Connect to relays only when needed
- **Resource Cleanup**: Proper cleanup of connections and subscriptions

#### Event Processing
- **Async Processing**: Non-blocking event processing
- **Batch Operations**: Efficient batch processing of multiple events
- **Memory Management**: Careful memory usage for large event volumes

#### UI Responsiveness
- **Background Processing**: Heavy operations moved to background
- **Progressive Loading**: Incremental UI updates
- **Caching**: Smart caching of frequently accessed data

### Error Handling and Resilience

#### Network Errors
- **Retry Logic**: Exponential backoff for failed operations
- **Fallback Mechanisms**: Alternative relays when primary fails
- **Timeout Handling**: Appropriate timeouts for different operations

#### Cryptographic Errors
- **Key Validation**: Comprehensive validation of all cryptographic inputs
- **Error Recovery**: Graceful handling of cryptographic failures
- **Secure Failure**: Fail securely without exposing sensitive data

#### Data Integrity
- **Event Verification**: Cryptographic verification of all events
- **Duplicate Detection**: Handle duplicate events from multiple sources
- **Consistency Checks**: Regular data consistency validation

### Security Considerations

#### Key Security
- **Secure Storage**: Platform-native secure storage for private keys
- **Memory Protection**: Secure memory clearing after key operations
- **Key Rotation**: Regular rotation of trade keys

#### Communication Security
- **End-to-End Encryption**: All trade communications encrypted
- **Metadata Protection**: NIP-59 hides communication metadata
- **Forward Secrecy**: Ephemeral keys provide forward secrecy

#### Privacy Protection
- **Unique Keys**: Different keys for each trade prevent linking
- **Traffic Analysis**: Protection against traffic analysis attacks
- **Data Minimization**: Collect and store only necessary data

## Development and Debugging

### Development Tools
- **Flutter DevTools**: Debugging and performance profiling
- **Nostr Debug Tools**: Custom tools for Nostr event inspection
- **Relay Monitoring**: Real-time relay connection monitoring

### Testing Strategy
- **Unit Tests**: Comprehensive unit test coverage
- **Integration Tests**: End-to-end integration testing
- **Mock Services**: Mockito-based service mocking
- **Crypto Testing**: Extensive cryptographic operation testing

### Common Issues and Solutions

#### Connection Issues
- **Problem**: Relay connectivity failures
- **Solution**: Implement proper retry logic and fallback relays

#### Key Management Issues
- **Problem**: Key derivation inconsistencies
- **Solution**: Strict adherence to BIP-32/NIP-06 standards

#### Message Delivery Issues
- **Problem**: Messages not reaching recipients
- **Solution**: Multi-relay publishing and delivery confirmation

## Future Enhancements

### Planned Improvements
- **Tor Support**: Anonymous relay connections through Tor
- **Lightning Integration**: Direct Lightning Network integration
- **Advanced Privacy**: Additional privacy-preserving features
- **Performance**: Further optimization for mobile devices

### Protocol Extensions
- **Multi-signature**: Support for multi-signature escrow
- **Atomic Swaps**: Direct Bitcoin/altcoin trading
- **Smart Contracts**: Integration with Bitcoin smart contracts

---

*This documentation is maintained as part of the Mostro Mobile project. For the latest updates and technical details, please refer to the source code and commit history.*