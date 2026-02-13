# NWC Phase 1: Core NWC Protocol Library

## Overview

This document describes the Phase 1 implementation of Nostr Wallet Connect (NWC / NIP-47) support in Mostro Mobile. Phase 1 focuses on the **core protocol library** — parsing connection URIs, modeling request/response payloads, and implementing a client that communicates with wallet services over Nostr relays.

## Why NWC?

Currently, Mostro Mobile handles Lightning payments by displaying invoices for the user to pay externally. NWC enables **in-app wallet integration**: users connect their Lightning wallet once, and the app can pay invoices, create invoices, and check balances on their behalf — all through encrypted Nostr messages.

This improves UX significantly: instead of copy-pasting invoices between apps, payments happen seamlessly within Mostro.

## Architecture

All NWC code lives under `lib/services/nwc/` with four files:

```text
lib/services/nwc/
├── nwc_connection.dart    # URI parsing & connection model
├── nwc_models.dart        # Request/response/command models
├── nwc_client.dart        # Core client (relay communication)
└── nwc_exceptions.dart    # Typed exceptions & error codes
```

### Design Decisions

1. **Reuse existing Nostr infrastructure**: The client uses `dart_nostr` (already in the project) for relay connections and event handling, and the `nip44` package for NIP-44 encryption — both already dependencies in `pubspec.yaml`.

2. **NostrService dependency injection**: `NwcClient` accepts a `NostrService` parameter following the app's architectural pattern of routing Nostr communication through `NostrService`. Internally, the client accesses `Nostr.instance` directly because `NostrService` does not yet expose granular relay subscription methods. The injected dependency is kept for a future refactor where NWC may use a dedicated Nostr instance with its own relay connections.

3. **Separate relay management**: NWC wallet relays may differ from Mostro relays. The client connects to wallet-specified relays through `Nostr.instance`, which handles deduplication (if the relay is already connected, it reuses the connection).

4. **Equatable models**: All models extend `Equatable` following the project's existing pattern (see `pubspec.yaml` dependency and usage in other models).

5. **No existing file modifications**: Phase 1 only adds new files. Integration with the UI and providers will come in Phase 2.

## Key Components

### NwcConnection (`nwc_connection.dart`)

Parses `nostr+walletconnect://` URIs as defined in NIP-47:

```dart
final conn = NwcConnection.fromUri(
  'nostr+walletconnect://<pubkey>?relay=wss://relay.example.com&secret=<hex>&lud16=user@example.com'
);
```

Extracts:
- **walletPubkey**: 32-byte hex public key of the wallet service
- **relayUrls**: One or more relay URLs (multiple `relay` params supported)
- **secret**: 32-byte hex secret used as the client's signing key
- **lud16**: Optional lightning address

Validation ensures:
- Correct URI scheme (`nostr+walletconnect://`)
- Valid 64-char hex for pubkey and secret
- Relay URLs start with `wss://` or `ws://`

Supports round-tripping via `toUri()`.

### NwcModels (`nwc_models.dart`)

Models the NIP-47 JSON-RPC-like protocol:

- **NwcRequest**: `{ method, params }` — the encrypted content of kind 23194 events
- **NwcResponse**: `{ result_type, error?, result? }` — decrypted from kind 23195 events
- **NwcError**: `{ code, message }` — structured error with typed `NwcErrorCode`

Command-specific models:
- `PayInvoiceParams` / `PayInvoiceResult` — invoice string, optional amount in msats, preimage and fees
- `MakeInvoiceParams` / `TransactionResult` — amount, description, expiry; shared result with `lookup_invoice`
- `LookupInvoiceParams` — lookup by payment hash or bolt11
- `GetBalanceResult` — balance in millisatoshis
- `GetInfoResult` — alias, network, supported methods and notifications

All models support `toMap()` / `fromMap()` serialization and extend `Equatable`.

### NwcClient (`nwc_client.dart`)

The core client that:

1. **Accepts** a `NwcConnection` and `NostrService` (dependency injection)
2. **Derives** a key pair from the connection secret via `NostrUtils.generateKeyPairFromPrivateKey()`
3. **Connects** to wallet relay(s) using `Nostr.instance.services.relays.init()`
4. **Signs** request events (kind 23194) with the connection secret
5. **Encrypts** payloads using NIP-44 via the `nip44` package (`Nip44.encryptMessage()`)
6. **Subscribes** to response events (kind 23195) filtered by wallet pubkey (`authors`), request event ID (`#e` tag), and client pubkey (`#p` tag)
7. **Decrypts** responses with `Nip44.decryptMessage()` and maps them to typed result objects
8. **Handles timeouts** (configurable, default 30s) with automatic subscription cleanup
9. **Null-safe result handling**: All public methods validate that `response.result` is non-null before parsing, throwing a meaningful `NwcException` instead of a `TypeError` on malformed wallet responses

Public API:

```dart
final client = NwcClient(connection: conn, nostrService: nostrService);
await client.connect();

final result = await client.payInvoice(PayInvoiceParams(invoice: 'lnbc...'));
final balance = await client.getBalance();
final info = await client.getInfo();
final invoice = await client.makeInvoice(MakeInvoiceParams(amount: 5000));
final lookup = await client.lookupInvoice(LookupInvoiceParams(paymentHash: '...'));

client.disconnect();
```

#### Subscription Lifecycle

Each request creates a temporary subscription (`nwc_<eventId>`) that is cleaned up in a `finally` block — ensuring cleanup happens even on timeout or error. The `disconnect()` method cancels all remaining subscriptions and closes them on the relay side via `closeEventsSubscription()`.

#### Known Limitation: Relay Disconnection

`Nostr.instance` is a shared singleton — its `disconnectFromRelays()` API closes *all* relay WebSockets (including Mostro's), and `dart_nostr` does not support closing individual relay connections. Until NWC gets a dedicated Nostr instance (future refactor), NWC relay connections not shared with Mostro will persist until the app is closed. This is tracked for Phase 2.

### NwcExceptions (`nwc_exceptions.dart`)

Exception hierarchy:
- `NwcException` — base class
  - `NwcInvalidUriException` — malformed connection URI
  - `NwcResponseException` — wallet returned an error (includes `NwcErrorCode`)
  - `NwcTimeoutException` — request timed out (uses `super.message` parameter)
  - `NwcNotConnectedException` — client not connected to relay (uses `super.message` parameter)

`NwcErrorCode` enum maps all NIP-47 error codes: `RATE_LIMITED`, `NOT_IMPLEMENTED`, `INSUFFICIENT_BALANCE`, `QUOTA_EXCEEDED`, `RESTRICTED`, `UNAUTHORIZED`, `INTERNAL`, `PAYMENT_FAILED`, `NOT_FOUND`, `UNSUPPORTED_ENCRYPTION`, `OTHER`.

## Encryption

NWC uses NIP-44 for E2E encryption between client and wallet service. The project already depends on the `nip44` package (from `MostroP2P/dart-nip44`), which is used extensively in `NostrUtils` for NIP-59 gift wraps. The NWC client uses the same `Nip44.encryptMessage()` / `Nip44.decryptMessage()` functions directly.

The encryption tag `nip44_v2` is included in all request events to indicate the encryption scheme, as specified in NIP-47's encryption negotiation protocol.

## Testing

Tests are in `test/services/nwc/` with **41 unit tests**:

- **`nwc_connection_test.dart`**: URI parsing — valid URIs, multiple relays, lud16, whitespace handling, round-trip via `toUri()`, and all error cases (wrong scheme, missing pubkey/relay/secret, invalid hex)
- **`nwc_models_test.dart`**: JSON serialization/deserialization for all models, edge cases (missing optional fields, unknown error codes, empty params)
- **`nwc_exceptions_test.dart`**: Error code mapping (`fromString`), exception hierarchy, `toString` output, super parameter usage

The `NwcClient` is not unit-tested in Phase 1 because it requires live relay connections. Integration tests will be added in Phase 2 when we add the provider layer.

## What's Next (Phase 2+)

- **Riverpod providers** for NWC state management
- **Secure storage** of connection URIs (using `flutter_secure_storage`)
- **UI integration**: QR scanner for connection URIs, wallet settings screen
- **Payment flow integration**: Replace manual invoice copy-paste with NWC `pay_invoice`
- **Balance display** in the app
- **Notification support** (kind 23197 events)
- **Dedicated Nostr instance** for NWC relay connections (resolves shared singleton limitation)

## References

- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NWC Developer Documentation](https://nwc.dev)
- [Issue #456](https://github.com/MostroP2P/mobile/issues/456)
