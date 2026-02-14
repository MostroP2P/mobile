# NWC Phase 1: Core NWC Protocol Library

## Overview

This document describes the Phase 1 implementation of Nostr Wallet Connect (NWC / NIP-47) support in Mostro Mobile. Phase 1 focuses on the **core protocol library** — parsing connection URIs, modeling request/response payloads, and implementing a client that communicates with wallet services over Nostr relays.

## Why NWC?

Currently, Mostro Mobile handles Lightning payments by displaying invoices for the user to pay externally. NWC enables **in-app wallet integration**: users connect their Lightning wallet once, and the app can pay invoices, create invoices, and check balances on their behalf — all through encrypted Nostr messages.

This improves UX significantly: instead of copy-pasting invoices between apps, payments happen seamlessly within Mostro.

## Architecture

All NWC code lives under `lib/services/nwc/` with five files:

```text
lib/services/nwc/
├── nwc_connection.dart    # URI parsing & connection model
├── nwc_models.dart        # Request/response/command models
├── nwc_client.dart        # Core client (relay communication)
├── nwc_crypto.dart        # NIP-04/NIP-44 encryption helpers
└── nwc_exceptions.dart    # Typed exceptions & error codes
```

### Design Decisions

1. **Reuse existing Nostr infrastructure**: The client uses `dart_nostr` (already in the project) for relay connections and event handling, `nip44` for NIP-44 encryption, and `pointycastle` for NIP-04 AES-256-CBC — all already dependencies in `pubspec.yaml`.

2. **NostrService dependency injection**: `NwcClient` accepts a `NostrService` parameter following the app's architectural pattern. Internally, the client uses a **dedicated `Nostr()` instance** (not the shared `Nostr.instance` singleton) to avoid interference with Mostro's relay pool.

3. **Dedicated relay instance**: NWC wallet relays differ from Mostro relays. The client creates its own `Nostr()` instance so subscriptions and events are sent **only** to the NWC wallet relay(s), not broadcast to all Mostro relays. Relay connections are fully managed and cleaned up on `disconnect()`.

4. **Dual encryption support (NIP-04 + NIP-44)**: On connect, the client fetches the wallet's info event (kind 13194) to detect supported encryption. If `nip44_v2` is advertised, NIP-44 is used; otherwise NIP-04 is assumed per the NIP-47 spec. Response decryption auto-detects the format from the content (`?iv=` = NIP-04).

5. **Equatable models**: All models extend `Equatable` following the project's existing pattern.

6. **No existing file modifications**: Phase 1 only adds new files. Integration with the UI and providers comes in Phase 2.

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

### NwcCrypto (`nwc_crypto.dart`)

Handles encryption/decryption for NWC protocol messages with dual mode support:

- **NIP-44** (preferred): ChaCha20-Poly1305 via the `nip44` package
- **NIP-04** (legacy): AES-256-CBC with ECDH shared secret via `pointycastle`

Key features:
- `encrypt()` / `decrypt()` — dispatch to NIP-04 or NIP-44 based on mode
- `detectFromContent()` — auto-detects encryption from content format (`?iv=` = NIP-04)
- `encryptionTagValue()` — returns the correct tag value for kind 23194 events
- PKCS#7 padding with full validation (all padding bytes verified)
- ECDH shared secret computation on secp256k1 for NIP-04

### NwcClient (`nwc_client.dart`)

The core client that:

1. **Accepts** a `NwcConnection` and `NostrService` (dependency injection)
2. **Derives** a key pair from the connection secret via `NostrUtils.generateKeyPairFromPrivateKey()`
3. **Connects** to wallet relay(s) using a **dedicated `Nostr()` instance** (isolated from Mostro's relay pool)
4. **Detects encryption mode** by fetching the wallet's info event (kind 13194) and reading the `encryption` tag
5. **Signs** request events (kind 23194) with the connection secret
6. **Encrypts** payloads using NIP-04 or NIP-44 via `NwcCrypto` based on the detected mode
7. **Subscribes** to response events (kind 23195) filtered by wallet pubkey (`authors`). The `e` tag match is verified in the event handler (not in the relay filter) for compatibility with custom relay implementations.
8. **Decrypts** responses with auto-detection of the encryption format
9. **Handles timeouts** (configurable, default 30s) with automatic subscription cleanup
10. **Null-safe result handling**: All public methods validate that `response.result` is non-null before parsing

Public API:

```dart
final client = NwcClient(connection: conn, nostrService: nostrService);
await client.connect(); // also detects encryption mode

final result = await client.payInvoice(PayInvoiceParams(invoice: 'lnbc...'));
final balance = await client.getBalance();
final info = await client.getInfo();
final invoice = await client.makeInvoice(MakeInvoiceParams(amount: 5000));
final lookup = await client.lookupInvoice(LookupInvoiceParams(paymentHash: '...'));

client.disconnect(); // cleans up subscriptions + disconnects relays
```

#### Subscription Lifecycle

Each request creates a temporary subscription (`nwc_<eventId>`) that is cleaned up in a `finally` block — ensuring cleanup happens even on timeout or error. The `disconnect()` method cancels all remaining subscriptions, closes them on the relay side, and disconnects the dedicated NWC relay connections.

#### Encryption Negotiation

On `connect()`, the client:
1. Connects to the wallet's relay(s)
2. Subscribes to kind 13194 (info event) from the wallet pubkey
3. If the info event has `['encryption', 'nip44_v2 ...']` → uses NIP-44
4. If no info event or no encryption tag → defaults to NIP-04 (per NIP-47 spec)
5. All subsequent requests use the detected mode

This ensures compatibility with both modern wallets (Alby Hub → NIP-44) and legacy wallets (Coinos → NIP-04).

### NwcExceptions (`nwc_exceptions.dart`)

Exception hierarchy:
- `NwcException` — base class
  - `NwcInvalidUriException` — malformed connection URI
  - `NwcResponseException` — wallet returned an error (includes `NwcErrorCode`)
  - `NwcTimeoutException` — request timed out
  - `NwcNotConnectedException` — client not connected to relay

`NwcErrorCode` enum maps all NIP-47 error codes: `RATE_LIMITED`, `NOT_IMPLEMENTED`, `INSUFFICIENT_BALANCE`, `QUOTA_EXCEEDED`, `RESTRICTED`, `UNAUTHORIZED`, `INTERNAL`, `PAYMENT_FAILED`, `NOT_FOUND`, `UNSUPPORTED_ENCRYPTION`, `OTHER`.

## Encryption

NWC supports both NIP-04 and NIP-44 encryption between client and wallet service. The encryption mode is **automatically negotiated** from the wallet's info event:

- **NIP-44** (ChaCha20-Poly1305): Preferred, used when wallet advertises `nip44_v2`. Uses the existing `nip44` package from `MostroP2P/dart-nip44`.
- **NIP-04** (AES-256-CBC): Legacy fallback, used when wallet has no encryption tag or advertises `nip04`. Implemented in `NwcCrypto` using `pointycastle` (already a project dependency).

The encryption tag (`nip44_v2` or `nip04`) is included in all request events per NIP-47's encryption negotiation protocol. Response decryption auto-detects the format from content structure as an additional safety measure.

## Testing

Tests are in `test/services/nwc/` with **41 unit tests**:

- **`nwc_connection_test.dart`**: URI parsing — valid URIs, multiple relays, lud16, whitespace handling, round-trip via `toUri()`, and all error cases (wrong scheme, missing pubkey/relay/secret, invalid hex)
- **`nwc_models_test.dart`**: JSON serialization/deserialization for all models, edge cases (missing optional fields, unknown error codes, empty params)
- **`nwc_exceptions_test.dart`**: Error code mapping (`fromString`), exception hierarchy, `toString` output, super parameter usage

The `NwcClient` is not unit-tested in Phase 1 because it requires live relay connections. Integration tests are added in Phase 2 with the provider layer.

## References

- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NWC Developer Documentation](https://nwc.dev)
- [Issue #456](https://github.com/MostroP2P/mobile/issues/456)
