# NWC Phase 3: Automatic Invoice Payment (Buyer Flow)

## Overview

Phase 3 integrates NWC into the Mostro payment flow, enabling **automatic invoice payment** when a seller needs to pay the escrow invoice. When an NWC wallet is connected, the user sees a "Pay with Wallet" button instead of (or in addition to) the manual QR code flow.

## How It Works

### Flow with NWC Connected

1. Seller takes a buy order (or buyer takes a sell order and seller needs to fund escrow)
2. Mostro daemon sends a `PaymentRequest` with an `lnInvoice`
3. `PayLightningInvoiceScreen` detects NWC connection via `nwcProvider`
4. User sees amount details + **"Pay with Wallet"** button with wallet balance
5. On tap → `NwcPaymentWidget` calls `nwcNotifier.payInvoice(invoice)`
6. Shows animated progress: sending → success ✅ or failure ❌
7. On success → navigates home; Mostro updates order state via event stream
8. On failure → shows error + "Retry" button + "Pay manually" fallback

### Flow without NWC (unchanged)

If no NWC wallet is connected, the original manual flow is shown: QR code + copy/share buttons. **No regression** — the NWC feature is purely additive.

### Fallback

If NWC payment fails, the user can tap "Pay manually instead" to switch to the QR code flow within the same screen. This ensures the user is never stuck.

## Architecture

### New Files

```text
lib/shared/widgets/nwc_payment_widget.dart    # Reusable NWC payment UI component
docs/NWC_PHASE3_IMPLEMENTATION.md             # This document
```

### Modified Files

```text
lib/features/order/screens/pay_lightning_invoice_screen.dart
  — Added NWC detection and conditional rendering
  — Shows NwcPaymentWidget when wallet connected, manual flow otherwise
  — Added _manualMode flag for fallback

lib/features/wallet/providers/nwc_provider.dart
  — Added payInvoice(invoice) method
  — Auto-refreshes balance after successful payment

lib/l10n/intl_en.arb, intl_es.arb, intl_it.arb
  — Added 11 NWC payment localization strings

lib/generated/l10n.dart, l10n_en.dart, l10n_es.dart, l10n_it.dart
  — Added generated getters for new localization strings
```

## Key Components

### NwcPaymentWidget (`lib/shared/widgets/nwc_payment_widget.dart`)

A self-contained `ConsumerStatefulWidget` that handles the full NWC payment lifecycle:

**States:**
- `idle` — Shows "Pay with Wallet" button with balance info
- `paying` — Animated spinner with "Sending payment..." message
- `success` — Green checkmark with preimage confirmation
- `failed` — Error message + retry button + manual fallback link

**Features:**
- Disables pay button if wallet balance < invoice amount
- Shows wallet balance below the button for transparency
- Handles all NWC error codes with user-friendly messages:
  - `INSUFFICIENT_BALANCE` → "Insufficient wallet balance"
  - `PAYMENT_FAILED` → "Payment failed. Please try again."
  - `RATE_LIMITED` → "Wallet is rate limited. Please wait a moment."
  - `QUOTA_EXCEEDED` → "Wallet spending quota exceeded"
  - Timeout → "Payment timed out. Please try again or pay manually."
- Retry button resets to idle state for another attempt
- "Pay manually instead" button triggers fallback callback

**Reusability:** Designed as a shared widget so it can be reused in Phase 4 (seller flow) or any other screen that needs to pay a Lightning invoice.

### NwcNotifier.payInvoice()

New method on the NWC provider:

```dart
Future<PayInvoiceResult> payInvoice(String invoice) async {
  // Validates connection, calls client.payInvoice(), refreshes balance
}
```

- Throws typed exceptions (`NwcResponseException`, `NwcTimeoutException`)
- Auto-refreshes wallet balance after successful payment
- Balance refresh failure is logged but doesn't break the payment result

### PayLightningInvoiceScreen Changes

The screen now:
1. Watches `nwcProvider` state
2. If connected + not in manual mode → shows `NwcPaymentWidget`
3. If disconnected or manual mode → shows original `PayLightningInvoiceWidget`
4. Cancel button always available in both modes

## Localization

Added 11 new strings in EN, ES, IT:

| Key | EN | ES | IT |
|-----|----|----|-----|
| payWithWallet | Pay with Wallet | Pagar con Billetera | Paga con Portafoglio |
| nwcPaymentSending | Sending payment... | Enviando pago... | Invio pagamento... |
| nwcPaymentSuccess | Payment Successful! | ¡Pago Exitoso! | Pagamento Riuscito! |
| nwcPaymentFailed | Payment failed... | El pago falló... | Pagamento fallito... |
| nwcPaymentTimeout | Payment timed out... | El pago expiró... | Pagamento scaduto... |
| nwcInsufficientBalance | Insufficient wallet balance | Saldo insuficiente... | Saldo insufficiente... |
| nwcRateLimited | Wallet is rate limited... | La billetera está limitada... | Il portafoglio è limitato... |
| nwcQuotaExceeded | Wallet spending quota exceeded | Cuota de gastos excedida | Quota di spesa superata |
| nwcRetryPayment | Retry Payment | Reintentar Pago | Riprova Pagamento |
| nwcPayManually | Pay manually instead | Pagar manualmente | Paga manualmente |

## Edge Cases Handled

1. **NWC disconnects mid-payment** → Timeout after 30s → error state → retry/manual fallback
2. **Invoice expires** → Wallet returns `PAYMENT_FAILED` → error shown with retry option
3. **Insufficient balance** → Button disabled + balance shown in red + message
4. **Balance unknown** → Button enabled (balance might be enough), let wallet decide
5. **Multiple screens** → Each `NwcPaymentWidget` is independent with its own state

## What's Next (Phase 4+)

- **Phase 4**: Auto invoice generation (seller receives payment via NWC `make_invoice`)
- **Phase 5**: Payment notifications (kind 23197 events)

## References

- [Phase 1: Core Library](NWC_PHASE1_IMPLEMENTATION.md)
- [Phase 2: Wallet Management UI](NWC_PHASE2_IMPLEMENTATION.md)
- [NIP-47: pay_invoice](https://github.com/nostr-protocol/nips/blob/master/47.md#pay_invoice)
- [Issue #458](https://github.com/MostroP2P/mobile/issues/458)
