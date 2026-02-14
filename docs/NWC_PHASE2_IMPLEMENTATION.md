# NWC Phase 2: Wallet Connection Management UI

## Overview

This document describes the Phase 2 implementation of Nostr Wallet Connect (NWC / NIP-47) in Mostro Mobile. Phase 2 builds on the [Phase 1 core library](NWC_PHASE1_IMPLEMENTATION.md) by adding **secure storage**, **state management**, **UI screens**, and critical **relay isolation** and **encryption compatibility** fixes discovered during real-world testing.

## Architecture

Phase 2 adds a new `wallet` feature module and a storage repository:

```text
lib/
├── data/repositories/
│   └── nwc_storage.dart              # Secure storage for NWC connection URI
├── features/wallet/
│   ├── providers/
│   │   └── nwc_provider.dart          # Riverpod StateNotifier + state model
│   ├── screens/
│   │   ├── wallet_settings_screen.dart # Main wallet management screen
│   │   └── connect_wallet_screen.dart  # URI paste & validation screen
│   └── widgets/
│       ├── wallet_status_card.dart     # Status card for Settings screen
│       └── wallet_balance_widget.dart  # Balance display widget
└── services/nwc/
    └── nwc_crypto.dart                # NEW: NIP-04/NIP-44 dual encryption
```

### Modified Files (from Phase 1)

- `lib/services/nwc/nwc_client.dart` — **Major changes:**
  - Dedicated `Nostr()` instance (replaces shared `Nostr.instance` singleton)
  - Encryption negotiation via info event (kind 13194)
  - Simplified relay filter (kind + authors only, e-tag verified in handler)
  - Full relay cleanup on `disconnect()`

### New Files

- `lib/services/nwc/nwc_crypto.dart` — NIP-04 + NIP-44 encryption helper
- `lib/data/repositories/nwc_storage.dart` — Secure storage wrapper
- `lib/features/wallet/providers/nwc_provider.dart` — Riverpod state management
- `lib/features/wallet/screens/wallet_settings_screen.dart` — Wallet management UI
- `lib/features/wallet/screens/connect_wallet_screen.dart` — URI input screen
- `lib/features/wallet/widgets/wallet_status_card.dart` — Settings status card
- `lib/features/wallet/widgets/wallet_balance_widget.dart` — Balance display

### Modified Files (existing)

- `lib/data/models/enums/storage_keys.dart` — Added `nwcConnectionUri` to `SecureStorageKeys`
- `lib/core/app_routes.dart` — Added `/wallet_settings` and `/connect_wallet` routes
- `lib/features/settings/settings_screen.dart` — Added wallet status card
- `lib/l10n/intl_en.arb`, `intl_es.arb`, `intl_it.arb` — Wallet localization strings

## Key Components

### NwcCrypto (`lib/services/nwc/nwc_crypto.dart`)

Handles encryption/decryption for NWC protocol messages with dual mode support. This was the most critical addition in Phase 2 — real-world testing revealed that wallets like Coinos use NIP-04 while others use NIP-44.

**NIP-04 (AES-256-CBC):**
- ECDH shared secret on secp256k1 (x-coordinate only)
- AES-256-CBC encryption with random 16-byte IV
- PKCS#7 padding with **full validation** (all padding bytes verified, not just the last)
- Content format: `base64?iv=base64`

**NIP-44 (ChaCha20-Poly1305):**
- Delegates to the `nip44` package
- Content format: pure base64 (no `?iv=` separator)

**Auto-detection:**
- `detectFromContent()` identifies encryption from content format
- Used as a safety fallback when decrypting responses

### NwcClient Changes

#### Dedicated Nostr Instance

The biggest architectural change: `NwcClient` now creates its own `Nostr()` instance instead of using the shared `Nostr.instance` singleton.

**Why this was necessary:** When using the shared singleton, `startEventsSubscription()` and `sendEventToRelaysAsync()` broadcast to ALL connected relays (Mostro + NWC). The NWC wallet relay received the request, but:
1. Subscriptions were primarily routed to Mostro relays (relay.mostro.network, nos.lol)
2. Responses from the NWC relay were not reliably delivered to the subscription stream
3. Custom NWC relays (like Primal's per-connection endpoints) were not properly integrated into the relay pool

With a dedicated instance, subscriptions and events go **only** to the wallet's relay(s).

#### Encryption Negotiation

On `connect()`, after establishing the relay connection:
1. Subscribes to kind 13194 (wallet info event) with a 5-second timeout
2. Reads the `encryption` tag: if `nip44_v2` is listed → NIP-44; otherwise → NIP-04
3. All subsequent requests use the detected mode
4. Request events include the appropriate `['encryption', 'nip04'|'nip44_v2']` tag

#### Simplified Response Filter

The subscription filter was simplified from:
```dart
NostrFilter(kinds: [23195], authors: [walletPubkey], e: [requestId], p: [clientPubkey])
```
to:
```dart
NostrFilter(kinds: [23195], authors: [walletPubkey])
```

The `e` tag match is verified in the event handler. This was necessary because some NWC relay implementations (e.g., Primal) don't support `#e`/`#p` tag filters in REQ subscriptions.

### NwcStorage (`lib/data/repositories/nwc_storage.dart`)

Thin wrapper around `FlutterSecureStorage` for persisting the NWC connection URI. The URI contains the wallet's secret key, so it is treated with the same security level as the app's mnemonic and master key.

```dart
final storage = NwcStorage(secureStorage: const FlutterSecureStorage());
await storage.saveConnection('nostr+walletconnect://...');
final uri = await storage.readConnection();
await storage.deleteConnection();
final hasConn = await storage.hasConnection();
```

Uses `SecureStorageKeys.nwcConnectionUri` for the storage key, following the same pattern as `KeyStorage`.

### NwcNotifier (`lib/features/wallet/providers/nwc_provider.dart`)

A `StateNotifier<NwcState>` that manages the full wallet connection lifecycle:

**States:**
- `NwcStatus.disconnected` — No wallet connected
- `NwcStatus.connecting` — Connection in progress
- `NwcStatus.connected` — Wallet connected with info and balance
- `NwcStatus.error` — Connection failed with error message

**Behavior:**
1. On creation, checks secure storage for a saved URI and auto-reconnects
2. `connect(uri)` — Parses URI, creates `NwcClient`, connects (with encryption detection), fetches `get_info` + `get_balance`, persists URI. If `get_info` or `get_balance` fail, connection still succeeds (info/balance shown as unknown/empty)
3. `disconnect()` — Disconnects client (cleans up subscriptions + relay connections), deletes stored URI, resets state
4. `refreshBalance()` / `refreshInfo()` — Updates wallet data without reconnecting

Storage failures are caught and logged without breaking the connection state.

**Providers:**

```dart
// Storage layer
final nwcStorageProvider = Provider<NwcStorage>((ref) => ...);

// Wallet state (auto-reconnects on init)
final nwcProvider = StateNotifierProvider<NwcNotifier, NwcState>((ref) => ...);
```

### UI Screens

#### WalletSettingsScreen (`/wallet_settings`)

The main wallet management screen. Shows:
- **Connected state:** Wallet alias, balance in sats (msats ÷ 1000 via integer division), supported methods, refresh and disconnect buttons
- **Disconnected state:** "Connect Wallet" button navigating to the connect screen
- **Error state:** Error message with retry option

#### ConnectWalletScreen (`/connect_wallet`)

URI input screen:
- Text field to paste NWC connection URI
- Real-time validation with error messages
- QR scanner button (placeholder for future implementation)
- On valid URI: triggers `connect()`, shows loading state, navigates back on success

#### WalletStatusCard

Compact card displayed in the Settings screen between the Lightning Address and Relays sections. Shows connected/disconnected status with wallet name. Tapping navigates to `/wallet_settings`.

#### WalletBalanceWidget

Displays the wallet balance in satoshis with a ⚡ icon and refresh button.

## Localization

Added wallet-related strings in all three languages (EN, ES, IT):

- `wallet`, `connectWallet`, `disconnectWallet`
- `walletConnected`, `walletDisconnected`, `walletConnecting`
- `walletBalance`, `walletSettings`, `walletInfo`
- `pasteNwcUri`, `scanQrCode`, `scanQrComingSoon`
- `invalidNwcUri`, `nwcConnectionError`
- `disconnectWalletConfirm`, `noWalletConnected`
- `supportedMethods`, `refreshBalance`, `sats`

## Bugs Found & Fixed During Testing

### 1. Shared Nostr Singleton (Critical)

**Problem:** `Nostr.instance` is shared with Mostro. Calling `init()` with NWC relays mixed them into the global pool. Subscriptions went to Mostro relays instead of the NWC relay.

**Fix:** Created a dedicated `Nostr()` instance per `NwcClient`. Subscriptions and events now go only to the wallet's relay(s). Relay connections are properly cleaned up on `disconnect()`.

### 2. NIP-04 vs NIP-44 Encryption (Critical)

**Problem:** Phase 1 hardcoded NIP-44 encryption. Many wallets (Coinos, others) only support NIP-04. The wallet couldn't decrypt our requests → never responded → timeout.

**Fix:** Added `NwcCrypto` helper with dual NIP-04/NIP-44 support. On connect, the client detects the wallet's supported encryption from the info event (kind 13194). Default is NIP-04 per NIP-47 spec.

### 3. Relay Tag Filters (Minor)

**Problem:** Some NWC relay implementations (Primal) don't support `#e`/`#p` tag filters in REQ subscriptions. The subscription filter was too specific.

**Fix:** Simplified filter to `kinds + authors` only. The `e` tag match is verified in the event handler code, which we already had.

## Security

- NWC connection URI stored in `FlutterSecureStorage` (same level as mnemonic/master key)
- Secret never displayed in UI or logged
- PKCS#7 padding fully validated (all bytes, not just last) to prevent silent decryption failures
- Dedicated relay instance prevents NWC traffic from leaking to Mostro relays and vice versa

## Testing

- `test/data/repositories/nwc_storage_test.dart` — Storage CRUD operations
- `test/features/wallet/providers/nwc_provider_test.dart` — State transitions, connect/disconnect flows

### Tested Wallets

| Wallet  | Relay                     | Encryption | Status |
|---------|---------------------------|------------|--------|
| Coinos  | wss://relay.coinos.io     | NIP-04     | ✅ Working |
| Primal  | wss://nwc.primal.net/...  | -          | ⚠️ Custom relay, no info event |

## What's Next (Phase 3+)

- **QR code scanning** for connection URIs (currently placeholder)
- **Deep link handling** for `nostr+walletconnect://` URIs
- **Auto invoice payment** (buyer flow) — Phase 3
- **Auto invoice generation** (seller flow) — Phase 4
- **Payment notifications** (kind 23197) — Phase 5

## References

- [Phase 1: Core NWC Protocol Library](NWC_PHASE1_IMPLEMENTATION.md)
- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [NWC Developer Documentation](https://nwc.dev)
- [Issue #457](https://github.com/MostroP2P/mobile/issues/457)
