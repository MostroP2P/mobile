# QR Scanner for NWC Wallet Import

## Overview

Implementation of QR code scanning for the Connect Wallet screen, enabling
users to scan `nostr+walletconnect://` URIs from compatible wallets (Alby,
Mutiny, etc.) instead of manually copy-pasting long connection strings.

## Why

NWC URIs are long and complex (`nostr+walletconnect://pubkey?relay=...&secret=...`).
On mobile, copying and pasting these from another app is error-prone. Most
NWC-compatible wallets display the connection string as a QR code, making
scanning the natural UX.

## Key Files

| File | Purpose |
|------|---------|
| `lib/shared/widgets/qr_scanner_screen.dart` | Reusable full-screen QR scanner widget |
| `lib/features/wallet/screens/connect_wallet_screen.dart` | Updated to launch scanner |
| `android/app/src/main/AndroidManifest.xml` | Added `CAMERA` permission |
| `pubspec.yaml` | Added `mobile_scanner` dependency |
| `lib/l10n/intl_*.arb` | Added `cameraPermissionDenied` string |

## Design Decisions

### Reusable `QrScannerScreen`

The scanner is a standalone `StatefulWidget` that returns the scanned value
via `Navigator.pop()`. It accepts an optional `uriPrefix` parameter to filter
codes — only QR codes starting with the specified prefix are accepted.

This makes it reusable for future scanning needs (Lightning invoices, Nostr
npubs, etc.) without modification.

### URI Prefix Filtering

The Connect Wallet screen passes `uriPrefix: 'nostr+walletconnect://'` so
random QR codes (URLs, Bitcoin addresses, etc.) are ignored. Only valid NWC
URIs trigger the scan callback.

### Camera Permission

- **Android**: `CAMERA` permission added to `AndroidManifest.xml`
- **iOS**: `NSCameraUsageDescription` was already present

Permission is requested at runtime via `permission_handler` (already a
dependency). If denied, a localized snackbar informs the user.

### Package Choice: `mobile_scanner`

`mobile_scanner` v7.x was chosen over alternatives because:
- Uses CameraX (Android) and AVFoundation (iOS) — native performance
- Actively maintained, supports Flutter 3.x
- Handles torch, camera switching, and barcode detection out of the box
- MIT licensed

## UX Flow

```text
1. User taps QR scan icon (now green/active instead of gray/disabled)
2. Camera permission requested (if not already granted)
3. Full-screen scanner opens with viewfinder overlay
4. User points camera at NWC QR code
5. Scanner detects and validates prefix
6. URI auto-fills in the text field
7. User taps "Connect Wallet" to complete
```
