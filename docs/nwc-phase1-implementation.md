# NWC Phase 1: Core NWC Protocol Library

## Overview

This document describes the Phase 1 implementation of Nostr Wallet Connect (NWC / NIP-47) support in Mostro Mobile. Phase 1 focuses on the **core protocol library** — parsing connection URIs, modeling request/response payloads, and implementing a client that communicates with wallet services over Nostr relays.

## Why NWC?

Currently, Mostro Mobile handles Lightning payments by displaying invoices for the user to pay externally. NWC enables **in-app wallet integration**: users connect their Lightning wallet once, and the app can pay invoices, create invoices, and check balances on their behalf — all through encrypted Nostr messages.

This improves UX significantly: instead of copy-pasting invoices between apps, payments happen seamlessly within Mostro.

## Architecture

All NWC code lives under `lib/services/nwc/` with four files:

```
lib/services/nwc/
├── nwc_connection.dart    # URI parsing & connection model
├── nwc_models.dart        # Request/response/command models  
├── nwc_client.dart        # Core client (relay communication)
└── nwc_exceptions.dart    # Typed exceptions & error codes
```

### Design Decisions

1. **Reuse existing Nostr infrastructure**: The client uses `dart_nostr` (already in the project) for relay connections and event handling, and the `nip44` package for NIP-44 encryption — both already dependencies in `pubspec.yaml`.

2. **Separate relay management**: NWC wallet relays may differ from Mostro relays. The client connects to wallet-specified relays through the same `Nostr.instance`, which handles deduplication (if the relay is already connected, it reuses the connection).

3. **Equatable models**: All models extend `Equatable` following the project's existing pattern (see `pubspec.yaml` dependency and usage in other models).

4. **No existing file modifications**: Phase 1 only adds new files. Integration with the UI and providers will come in Phase 2.

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
- Correct URI scheme
- Valid 64-char hex for pubkey and secret
- Relay URLs start with `wss://` or `ws://`

### NwcModels (`nwc_models.dart`)

Models the NIP-47 JSON-RPC-like protocol:

- **NwcRequest**: `{ method, params }` — the encrypted content of kind 23194 events
- **NwcResponse**: `{ result_type, error?, result? }` — decrypted from kind 23195 events
- **NwcError**: `{ code, message }` — structured error with typed `NwcErrorCode`

Command-specific models:
- `PayInvoiceParams` / `PayInvoiceResult`
- `MakeInvoiceParams` / `TransactionResult` (shared with `lookup_invoice`)
- `LookupInvoiceParams`
- `GetBalanceResult`
- `GetInfoResult`

### NwcClient (`nwc_client.dart`)

The core client that:

1. **Connects** to wallet relay(s) using `dart_nostr`
2. **Signs** request events (kind 23194) with the connection secret
3. **Encrypts** payloads using NIP-44 via the `nip44` package
4. **Subscribes** to response events (kind 23195) filtered by wallet pubkey and client pubkey
5. **Decrypts** responses and maps them to typed result objects
6. **Handles timeouts** (configurable, default 30s)

Public API:
```dart
final client = NwcClient(connection: conn);
await client.connect();

final result = await client.payInvoice(PayInvoiceParams(invoice: 'lnbc...'));
final balance = await client.getBalance();
final info = await client.getInfo();
final invoice = await client.makeInvoice(MakeInvoiceParams(amount: 5000));
final lookup = await client.lookupInvoice(LookupInvoiceParams(paymentHash: '...'));

client.disconnect();
```

### NwcExceptions (`nwc_exceptions.dart`)

Exception hierarchy:
- `NwcException` — base
  - `NwcInvalidUriException` — malformed connection URI
  - `NwcResponseException` — wallet returned an error (includes `NwcErrorCode`)
  - `NwcTimeoutException` — request timed out
  - `NwcNotConnectedException` — client not connected to relay

`NwcErrorCode` enum maps all NIP-47 error codes: `RATE_LIMITED`, `NOT_IMPLEMENTED`, `INSUFFICIENT_BALANCE`, `QUOTA_EXCEEDED`, `RESTRICTED`, `UNAUTHORIZED`, `INTERNAL`, `PAYMENT_FAILED`, `NOT_FOUND`, `UNSUPPORTED_ENCRYPTION`, `OTHER`.

## Encryption

NWC uses NIP-44 for E2E encryption between client and wallet service. The project already depends on the `nip44` package (from `MostroP2P/dart-nip44`), which is used extensively in `NostrUtils` for NIP-59 gift wraps. The NWC client uses the same `Nip44.encryptMessage()` / `Nip44.decryptMessage()` functions directly.

The encryption tag `nip44_v2` is included in all request events to indicate the encryption scheme, as specified in NIP-47's encryption negotiation protocol.

## Testing

Tests are in `test/services/nwc/`:

- **`nwc_connection_test.dart`**: URI parsing — valid URIs, multiple relays, lud16, whitespace handling, and all error cases (wrong scheme, missing pubkey/relay/secret, invalid hex)
- **`nwc_models_test.dart`**: JSON serialization/deserialization for all models, edge cases (missing optional fields, unknown error codes)
- **`nwc_exceptions_test.dart`**: Error code mapping, exception hierarchy, toString output

The `NwcClient` is not unit-tested in Phase 1 because it requires live relay connections. Integration tests will be added in Phase 2 when we add the provider layer.

## What's Next (Phase 2+)

- **Riverpod providers** for NWC state management
- **Secure storage** of connection URIs (using `flutter_secure_storage`)
- **UI integration**: QR scanner for connection URIs, wallet settings screen
- **Payment flow integration**: Replace manual invoice copy-paste with NWC `pay_invoice`
- **Balance display** in the app
- **Notification support** (kind 23197 events)

## References

- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NWC Developer Documentation](https://nwc.dev)
- [Issue #456](https://github.com/MostroP2P/mobile/issues/456)
