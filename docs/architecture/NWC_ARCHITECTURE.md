# Nostr Wallet Connect (NWC) Architecture

## Overview

Mostro Mobile integrates [NIP-47 (Nostr Wallet Connect)](https://github.com/nostr-protocol/nips/blob/master/47.md) to enable in-app Lightning wallet operations. Instead of copy-pasting invoices between apps, users connect their Lightning wallet once and the app handles payments and invoice generation seamlessly through encrypted Nostr messages.

## Why NWC

Without NWC, Lightning payments require manual copy-paste between Mostro and an external wallet app. NWC eliminates this friction by allowing the app to pay invoices, generate invoices, and check balances on the user's behalf — all through encrypted Nostr relay communication.

## Core Library (`lib/services/nwc/`)

```text
lib/services/nwc/
├── nwc_connection.dart    # URI parsing & connection model
├── nwc_models.dart        # Request/response/command models
├── nwc_client.dart        # Core client (relay communication)
├── nwc_crypto.dart        # NIP-04/NIP-44 encryption helpers
└── nwc_exceptions.dart    # Typed exceptions & error codes
```

### NwcConnection

Parses `nostr+walletconnect://` URIs as defined in NIP-47, extracting:
- **walletPubkey**: 32-byte hex public key of the wallet service
- **relayUrls**: One or more relay URLs (multiple `relay` params supported)
- **secret**: 32-byte hex secret used as the client's signing key
- **lud16**: Optional lightning address

Validates URI scheme, hex format (64-char for pubkey and secret), and relay URL protocol (`wss://` or `ws://`). Supports round-tripping via `toUri()`.

### NwcClient

The core client that manages the full NWC communication lifecycle:

1. Accepts a `NwcConnection` and `NostrService` (dependency injection)
2. Derives a key pair from the connection secret
3. Connects to wallet relay(s) using a **dedicated `Nostr()` instance** (isolated from Mostro's relay pool)
4. Detects encryption mode by fetching the wallet's info event (kind 13194)
5. Signs request events (kind 23194) with the connection secret
6. Encrypts/decrypts payloads via `NwcCrypto` based on the detected mode
7. Subscribes to response events (kind 23195) filtered by wallet pubkey
8. Subscribes to notification events (kind 23196) for real-time payment updates
9. Handles timeouts (configurable, default 30s) with automatic subscription cleanup

**Public API:**
```dart
final client = NwcClient(connection: conn, nostrService: nostrService);
await client.connect();

final result = await client.payInvoice(PayInvoiceParams(invoice: 'lnbc...'));
final balance = await client.getBalance();
final info = await client.getInfo();
final invoice = await client.makeInvoice(MakeInvoiceParams(amount: 5000));
final lookup = await client.lookupInvoice(LookupInvoiceParams(paymentHash: '...'));
Stream<NwcNotification> get notifications;

client.disconnect();
```

**Subscription lifecycle:** Each request creates a temporary subscription (`nwc_<eventId>`) cleaned up in a `finally` block. `disconnect()` cancels all remaining subscriptions, closes relay-side subscriptions, and disconnects NWC relay connections.

### NwcCrypto

Handles dual encryption for NWC protocol messages:

- **NIP-44** (preferred): ChaCha20-Poly1305 via the `nip44` package
- **NIP-04** (legacy): AES-256-CBC with ECDH shared secret via `pointycastle`, PKCS#7 padding with full validation

Auto-detection via `detectFromContent()` identifies encryption from content format (`?iv=` separator indicates NIP-04).

### NwcModels

Models the NIP-47 JSON-RPC-like protocol:
- `NwcRequest` / `NwcResponse` / `NwcError` — core protocol models
- `PayInvoiceParams` / `PayInvoiceResult` — invoice payment
- `MakeInvoiceParams` / `TransactionResult` — invoice generation and lookup
- `LookupInvoiceParams` — lookup by payment hash or bolt11
- `GetBalanceResult` / `GetInfoResult` — wallet state queries
- `NwcNotification` — real-time payment notifications (kind 23196)

All models support `toMap()` / `fromMap()` serialization and extend `Equatable`.

### NwcExceptions

Exception hierarchy:
- `NwcException` (base)
  - `NwcInvalidUriException` — malformed connection URI
  - `NwcResponseException` — wallet returned an error (includes `NwcErrorCode`)
  - `NwcTimeoutException` — request timed out
  - `NwcNotConnectedException` — client not connected to relay

`NwcErrorCode` maps all NIP-47 error codes: `RATE_LIMITED`, `NOT_IMPLEMENTED`, `INSUFFICIENT_BALANCE`, `QUOTA_EXCEEDED`, `RESTRICTED`, `UNAUTHORIZED`, `INTERNAL`, `PAYMENT_FAILED`, `NOT_FOUND`, `UNSUPPORTED_ENCRYPTION`, `OTHER`.

## Key Design Decisions

### Dedicated Nostr Instance

`NwcClient` creates its own `Nostr()` instance instead of using the shared `Nostr.instance` singleton. When the shared singleton was used, `startEventsSubscription()` and `sendEventToRelaysAsync()` broadcast to ALL connected relays (Mostro + NWC). The NWC wallet relay received requests, but responses were not reliably delivered because subscriptions were primarily routed to Mostro relays. With a dedicated instance, all communication goes only to the wallet's relay(s).

### Encryption Negotiation

On `connect()`, the client:
1. Subscribes to kind 13194 (wallet info event) with a 5-second timeout
2. If the info event has `['encryption', 'nip44_v2 ...']` → uses NIP-44
3. If no info event or no encryption tag → defaults to NIP-04 (per NIP-47 spec)

This ensures compatibility with both modern wallets (Alby Hub → NIP-44) and legacy wallets (Coinos → NIP-04).

### Simplified Response Filter

The subscription filter uses `kinds + authors` only (not `#e`/`#p` tag filters) because some NWC relay implementations (e.g., Primal) don't support tag filters in REQ subscriptions. The `e` tag match is verified in the event handler.

## Wallet Connection Management

### Storage (`lib/data/repositories/nwc_storage.dart`)

NWC connection URI is stored in `FlutterSecureStorage` (same security level as mnemonic/master key). The URI contains the wallet's secret key.

### State Management (`lib/features/wallet/providers/nwc_provider.dart`)

`NwcNotifier` is a `StateNotifier<NwcState>` managing the full connection lifecycle:

**States:** `disconnected` → `connecting` → `connected` (with info/balance) | `error`

**Behavior:**
- On creation, checks secure storage for a saved URI and auto-reconnects
- `connect(uri)` — parses, connects, detects encryption, fetches info + balance, persists URI
- `disconnect()` — cleans up subscriptions + relay connections, deletes stored URI
- `payInvoice(invoice)` — pays Lightning invoice, auto-refreshes balance
- `makeInvoice(amountSats)` — generates invoice (converts sats → msats internally)
- `preFlightBalanceCheck(amountSats)` — refreshes balance and checks sufficiency before payment
- `lookupInvoice()` — cross-references payment status on wallet side
- `refreshBalance()` / `refreshInfo()` — updates wallet data without reconnecting

### Connection Resilience

**Auto-reconnect:** When connection drops (detected via health check timeout or notification stream error):
- Exponential backoff: 2s, 4s, 8s, 16s, 32s (up to 5 attempts)
- Each attempt goes through the full `connect()` flow
- After 5 failures, stops retrying (manual reconnect available)

**Periodic health checks:** Every 30s, a lightweight `get_balance` call verifies the connection. Timeout sets `connectionHealthy = false` and triggers auto-reconnect.

**Periodic balance refresh:** Every 60s, balance is refreshed to stay current.

## Payment Integration

### Invoice Payment (Seller Flow)

When a seller needs to pay the escrow hold invoice and NWC is connected:

1. `PayLightningInvoiceScreen` detects NWC via `nwcProvider`
2. Shows `NwcPaymentWidget` with "Pay with Wallet" button and balance
3. Pre-flight balance check before initiating payment
4. Animated progress: checking → sending → success (with receipt) or failure
5. On failure: retry button + "Pay manually instead" fallback to QR code flow

### Invoice Generation (Buyer Flow)

When a buyer needs to provide a Lightning invoice (no Lightning Address set) and NWC is connected:

1. `AddLightningInvoiceScreen` detects NWC via `nwcProvider`
2. Shows `NwcInvoiceWidget` with "Generate with Wallet" button
3. On success: shows invoice preview + "Confirm & Submit" button
4. On failure: retry + "Enter manually instead" fallback

### Payment Priority

```text
Lightning Address (fully automatic, server-side)
    → NWC (one-tap generate/pay)
        → Manual paste (full manual control)
```

Lightning Address takes precedence because it requires zero interaction. NWC is the middle ground. Manual is always available as fallback.

### Real-time Notifications (Kind 23196)

The client subscribes to kind 23196 events from the wallet after connecting. `NwcNotificationListener` (integrated at app level in `app.dart`) shows floating snackbar notifications for received/sent payments. Balance auto-refreshes on notification arrival.

## UI Components

### Screens (`lib/features/wallet/screens/`)
- **WalletSettingsScreen** (`/wallet_settings`) — connection status, balance, supported methods, health indicator, disconnect
- **ConnectWalletScreen** (`/connect_wallet`) — URI paste + QR scanner

### Shared Widgets (`lib/shared/widgets/`)
- **NwcPaymentWidget** — self-contained payment lifecycle (idle → checking → paying → success/failed)
- **NwcInvoiceWidget** — self-contained invoice generation lifecycle
- **NwcPaymentReceiptWidget** — amount, routing fees, total, timestamp, preimage with copy
- **NwcConnectionStatusIndicator** — compact health indicator (green/orange/red)
- **NwcNotificationListener** — app-level payment notification snackbars
- **QrScannerScreen** — reusable full-screen QR scanner with URI prefix filtering

### Settings Integration
- **WalletStatusCard** — compact card in Settings showing connected/disconnected status
- **WalletBalanceWidget** — balance display with refresh button

## QR Scanner

`QrScannerScreen` is a standalone `StatefulWidget` that returns scanned values via `Navigator.pop()`. It accepts an optional `uriPrefix` parameter to filter codes (only QR codes starting with the specified prefix are accepted). Uses `mobile_scanner` package with CameraX (Android) and AVFoundation (iOS).

The Connect Wallet screen passes `uriPrefix: 'nostr+walletconnect://'` so only valid NWC URIs are accepted.

## Security

- NWC connection URI stored in `FlutterSecureStorage` (same level as mnemonic)
- Secret never displayed in UI or logged
- PKCS#7 padding fully validated (all bytes, not just last)
- Dedicated relay instance prevents NWC traffic leaking to Mostro relays
- Notification events verified via `p` tag to ensure they're addressed to our client
- Auto-reconnect reuses the stored URI (already in secure storage)

## Tested Wallets

| Wallet  | Relay                     | Encryption | Status |
|---------|---------------------------|------------|--------|
| Coinos  | wss://relay.coinos.io     | NIP-04     | Working |
| Primal  | wss://nwc.primal.net/...  | -          | Custom relay, no info event |

## Testing

- `test/services/nwc/nwc_connection_test.dart` — URI parsing (valid, invalid, round-trip)
- `test/services/nwc/nwc_models_test.dart` — JSON serialization for all models
- `test/services/nwc/nwc_exceptions_test.dart` — Error code mapping, exception hierarchy
- `test/data/repositories/nwc_storage_test.dart` — Storage CRUD
- `test/features/wallet/providers/nwc_provider_test.dart` — State transitions, connect/disconnect

## References

- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NWC Developer Documentation](https://nwc.dev)
- [Mostro Protocol](https://mostro.network/protocol/) — for understanding the order flows that NWC integrates with
