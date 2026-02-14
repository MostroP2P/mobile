# NWC Phase 5: Payment Notifications and Enhanced UX

## Overview

Phase 5 is the final phase of NWC integration in Mostro Mobile. It adds **real-time payment notifications** via NIP-47 kind 23196 events, **enhanced payment UX** with pre-flight balance checks and payment receipts, **connection resilience** with auto-reconnect, and **wallet health monitoring** throughout the app.

## Architecture

### Modified Files

```text
lib/services/nwc/nwc_client.dart
  — Added NwcNotification model
  — Added notification stream (kind 23196 subscription)
  — Added _subscribeToNotifications() for real-time wallet events

lib/features/wallet/providers/nwc_provider.dart
  — Added connection health tracking (connectionHealthy, lastSuccessfulContact)
  — Added auto-reconnect with exponential backoff on connection drops
  — Added periodic balance refresh (every 60s)
  — Added connection health checks (every 30s)
  — Added notification stream forwarding to UI
  — Added preFlightBalanceCheck() method
  — Added lookupInvoice() method for payment verification
  — Proper cleanup of timers and subscriptions

lib/shared/widgets/nwc_payment_widget.dart
  — Added pre-flight balance check step before payment
  — Added connection health warnings
  — Added low balance warnings
  — Replaced simple success indicator with full payment receipt
  — Added lookup_invoice verification after payment

lib/features/wallet/screens/wallet_settings_screen.dart
  — Connection health indicator (green/orange dot)

lib/core/app.dart
  — Integrated NwcNotificationListener at app level

lib/l10n/intl_en.arb, intl_es.arb, intl_it.arb
  — Added 14 new localization strings for Phase 5 features
```

### New Files

```text
lib/shared/widgets/nwc_connection_status_indicator.dart
  — Compact connection health indicator widget

lib/shared/widgets/nwc_payment_receipt_widget.dart
  — Payment receipt with amount breakdown, fees, preimage, timestamp

lib/shared/widgets/nwc_notification_listener.dart
  — App-level listener that shows snackbar notifications for payment events

docs/NWC_PHASE5_IMPLEMENTATION.md
  — This document
```

## Key Components

### Real-time Notifications (NIP-47 kind 23196)

The NWC client now subscribes to kind 23196 events from the wallet after connecting. These are notification events defined in NIP-47 for real-time payment updates.

**NwcClient changes:**

```dart
class NwcNotification {
  final String notificationType; // "payment_received", "payment_sent"
  final TransactionResult transaction;
}

// Stream exposed on NwcClient
Stream<NwcNotification> get notifications;
```

On `connect()`, after encryption detection, the client calls `_subscribeToNotifications()` which:
1. Creates a subscription for kind 23196 events from the wallet pubkey
2. Verifies the `p` tag matches the client pubkey (events addressed to us)
3. Decrypts the payload using the negotiated encryption mode
4. Parses the `NwcResponse` and extracts the `TransactionResult`
5. Emits the notification on the broadcast stream

**NwcNotifier** forwards these notifications to a UI-accessible stream and auto-refreshes the balance when `payment_received` or `payment_sent` events arrive.

**NwcNotificationListener** is integrated at the app level (`app.dart` builder) and shows floating snackbar notifications with:
- Green arrow-down icon for received payments
- Orange arrow-up icon for sent payments
- Amount in sats

### Enhanced Payment UX

#### Pre-flight Balance Check

Before initiating a payment, `NwcPaymentWidget` now:
1. Shows a "Checking balance..." state
2. Calls `nwcNotifier.preFlightBalanceCheck(amountSats)`
3. Refreshes the cached balance from the wallet
4. If insufficient, shows error immediately (saves the user a failed payment attempt)
5. If balance is unknown (check failed), proceeds anyway (let the wallet decide)

#### Payment Receipt

After successful payment, instead of a simple checkmark, the widget now shows `NwcPaymentReceiptWidget` with:
- Amount paid in sats
- Routing fees (if reported by the wallet, converted from msats)
- Total (amount + fees)
- Timestamp
- Preimage with copy-to-clipboard button

#### lookup_invoice Verification

After a successful `pay_invoice`, the widget calls `lookupInvoice()` in the background to cross-reference the payment status on the wallet side. This provides extra reliability — if Mostro's confirmation is delayed, the wallet's own record confirms the payment went through. The result is logged but doesn't block the UI flow.

### Connection Resilience

#### Auto-reconnect

When the NWC connection drops (detected via health check timeout or notification stream error):
1. The notifier saves the connection URI on initial connect
2. On drop detection, it triggers reconnect with exponential backoff
3. Delays: 2s, 4s, 8s, 16s, 32s (up to 5 attempts)
4. Each reconnect attempt goes through the full `connect()` flow
5. After 5 failed attempts, stops retrying (user can manually reconnect)

#### Periodic Health Checks

Every 30 seconds, the notifier performs a lightweight `get_balance` call to verify the connection is alive. If the call times out:
- `connectionHealthy` is set to `false`
- Auto-reconnect is triggered
- UI shows orange indicators instead of green

#### Periodic Balance Refresh

Every 60 seconds, the notifier refreshes the wallet balance. This ensures the displayed balance stays reasonably current even without explicit user action. The refresh also serves as a soft health check.

#### Connection Health Indicator

`NwcConnectionStatusIndicator` is a compact widget showing:
- Green wallet icon + "Connected" when healthy
- Orange wifi-off icon + "Connection unstable" when unhealthy
- Orange refresh icon + "Reconnecting..." during reconnect
- Red alert icon + "Connection error" on error
- Hidden when no wallet is configured

The wallet settings screen also shows green/orange dot based on health.

#### Graceful Degradation

`NwcPaymentWidget` shows a connection health warning banner when the connection is unstable but still connected. The "Pay manually instead" fallback remains available at all times after a failed payment, ensuring the user is never stuck if NWC becomes unreachable mid-trade.

### Wallet Balance in App

Balance is refreshed:
1. On initial connect (via `get_balance`)
2. Every 60 seconds via periodic timer
3. After every `pay_invoice` and `make_invoice`
4. When `payment_received` or `payment_sent` notifications arrive
5. On manual refresh via wallet settings

The `NwcPaymentWidget` shows the balance below the "Pay with Wallet" button with color coding:
- Normal color when balance >= payment amount
- Red when balance < payment amount (button disabled)

## Localization

Added 14 new strings in EN, ES, IT:

| Key | EN |
|-----|----|
| nwcConnectionUnstable | Connection unstable |
| nwcReconnecting | Reconnecting... |
| nwcBalanceTooLow | Wallet balance is lower than the payment amount |
| nwcCheckingBalance | Checking balance... |
| nwcReceiptAmount | Amount |
| nwcReceiptFees | Routing fees |
| nwcReceiptTotal | Total |
| nwcReceiptTimestamp | Time |
| nwcReceiptDone | Done |
| nwcPreimageCopied | Preimage copied to clipboard |
| nwcPaymentReceived | Payment received! |
| nwcPaymentSent | Payment sent! |
| nwcNotificationPaymentReceived | Received {amount} sats |
| nwcNotificationPaymentSent | Sent {amount} sats |

Note: `nwcConnectionError`, `nwcPaymentSuccess`, and `nwcPreimageLabel` were already added in Phases 2-3.

## State Changes

### NwcState

Two new fields added:

```dart
class NwcState {
  // ... existing fields ...
  final bool connectionHealthy;      // Whether relay communication is working
  final int? lastSuccessfulContact;   // Timestamp of last successful wallet call
}
```

### NwcNotifier

New public methods:

```dart
// Pre-flight balance check before payment
Future<bool> preFlightBalanceCheck(int amountSats);

// Lookup an invoice for payment verification
Future<TransactionResult?> lookupInvoice({String? paymentHash, String? invoice});

// Stream of payment notifications for UI consumption
Stream<NwcNotification> get notifications;
```

### NwcPaymentWidget

New payment status: `checking` (between `idle` and `paying`) for the pre-flight balance check step.

## Security

- Notification events are verified via `p` tag to ensure they're addressed to our client
- Notification decryption uses the same negotiated encryption mode as requests
- Auto-reconnect reuses the stored URI (already in secure storage)
- No new sensitive data is stored or exposed

## References

- [Phase 1: Core Library](NWC_PHASE1_IMPLEMENTATION.md)
- [Phase 2: Wallet Management UI](NWC_PHASE2_IMPLEMENTATION.md)
- [Phase 3: Automatic Hold Invoice Payment](NWC_PHASE3_IMPLEMENTATION.md)
- [Phase 4: Automatic Invoice Generation](NWC_PHASE4_IMPLEMENTATION.md)
- [NIP-47: Notification Events](https://github.com/nostr-protocol/nips/blob/master/47.md#notification-events)
- [Issue #460](https://github.com/MostroP2P/mobile/issues/460)
