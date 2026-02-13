# NWC Phase 2: Wallet Connection Management UI

## Overview

This document describes the Phase 2 implementation of Nostr Wallet Connect (NWC / NIP-47) in Mostro Mobile. Phase 2 builds on the [Phase 1 core library](NWC_PHASE1_IMPLEMENTATION.md) by adding **secure storage**, **state management**, and **UI screens** for users to connect, manage, and disconnect their NWC wallets.

## Architecture

Phase 2 adds a new `wallet` feature module and a storage repository:

```text
lib/
├── data/repositories/
│   └── nwc_storage.dart              # Secure storage for NWC connection URI
└── features/wallet/
    ├── providers/
    │   └── nwc_provider.dart          # Riverpod StateNotifier + state model
    ├── screens/
    │   ├── wallet_settings_screen.dart # Main wallet management screen
    │   └── connect_wallet_screen.dart  # URI paste & validation screen
    └── widgets/
        ├── wallet_status_card.dart     # Status card for Settings screen
        └── wallet_balance_widget.dart  # Balance display widget
```

### Modified Files

- `lib/data/models/enums/storage_keys.dart` — Added `nwcConnectionUri` to `SecureStorageKeys`
- `lib/core/app_routes.dart` — Added `/wallet_settings` and `/connect_wallet` routes
- `lib/features/settings/settings_screen.dart` — Added wallet status card
- `lib/l10n/intl_en.arb`, `intl_es.arb`, `intl_it.arb` — Wallet localization strings

## Key Components

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
2. `connect(uri)` — Parses URI, creates `NwcClient`, connects, fetches `get_info` + `get_balance`, persists URI
3. `disconnect()` — Disconnects client, deletes stored URI, resets state
4. `refreshBalance()` / `refreshInfo()` — Updates wallet data without reconnecting

**Providers:**

```dart
// Storage layer
final nwcStorageProvider = Provider<NwcStorage>((ref) => ...);

// Wallet state (auto-reconnects on init)
final nwcProvider = StateNotifierProvider<NwcNotifier, NwcState>((ref) => ...);
```

### WalletSettingsScreen (`lib/features/wallet/screens/wallet_settings_screen.dart`)

The main wallet management screen at route `/wallet_settings`. Shows:

- **Connected state:** Wallet alias, balance in sats (converted from msats), supported methods, refresh and disconnect buttons
- **Disconnected state:** "Connect Wallet" button navigating to the connect screen
- **Error state:** Error message with retry option

### ConnectWalletScreen (`lib/features/wallet/screens/connect_wallet_screen.dart`)

URI input screen at route `/connect_wallet`:

- Text field to paste NWC connection URI
- Real-time validation with error messages
- QR scanner button (placeholder for future implementation)
- On valid URI: triggers `connect()`, shows loading state, navigates back on success

### WalletStatusCard (`lib/features/wallet/widgets/wallet_status_card.dart`)

Compact card displayed in the Settings screen between the Lightning Address and Relays sections. Shows connected/disconnected status with wallet name. Tapping navigates to `/wallet_settings`.

### WalletBalanceWidget (`lib/features/wallet/widgets/wallet_balance_widget.dart`)

Displays the wallet balance in satoshis with a ⚡ icon and refresh button. Used within WalletSettingsScreen.

## Localization

Added wallet-related strings in all three languages (EN, ES, IT):

- `wallet`, `connectWallet`, `disconnectWallet`
- `walletConnected`, `walletDisconnected`, `walletConnecting`
- `walletBalance`, `walletSettings`, `walletInfo`
- `pasteNwcUri`, `scanQrCode`, `scanQrComingSoon`
- `invalidNwcUri`, `nwcConnectionError`
- `disconnectWalletConfirm`, `noWalletConnected`
- `supportedMethods`, `refreshBalance`, `sats`

## UI Design

Follows the existing Settings screen patterns:
- `AppTheme` colors (backgroundCard, backgroundInput, textPrimary, textSecondary, activeColor)
- Card containers with `borderRadius: 12`, `border: white 0.1 alpha`
- `lucide_icons` for icons (LucideIcons.wallet, etc.)
- `heroicons` for navigation (back arrow)
- GoRouter navigation with `context.push()`

## Security

The NWC connection URI contains a 32-byte hex secret that can authorize payments from the user's wallet. It is stored using `FlutterSecureStorage`, the same mechanism used for the app's mnemonic and master key. The secret is never displayed in the UI or logged.

## Testing

- `test/data/repositories/nwc_storage_test.dart` — Storage CRUD operations
- `test/features/wallet/providers/nwc_provider_test.dart` — State transitions, connect/disconnect flows

## What's Next (Phase 3+)

- **QR code scanning** for connection URIs (currently placeholder)
- **Deep link handling** for `nostr+walletconnect://` URIs
- **Auto invoice payment** (buyer flow) — Phase 3
- **Auto invoice generation** (seller flow) — Phase 4
- **Payment notifications** — Phase 5

## References

- [Phase 1: Core NWC Protocol Library](NWC_PHASE1_IMPLEMENTATION.md)
- [NIP-47: Nostr Wallet Connect](https://github.com/nostr-protocol/nips/blob/master/47.md)
- [Issue #457](https://github.com/MostroP2P/mobile/issues/457)
