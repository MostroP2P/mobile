# NWC Phase 4: Automatic Invoice Generation for Buyers via NWC

## Overview

Phase 4 integrates NWC's `make_invoice` capability into the buyer flow. When a buyer's order is matched and Mostro requests a Lightning invoice, the app can now automatically generate one using the connected NWC wallet — eliminating the need for manual invoice creation and pasting.

## How It Works

### Priority Flow (Lightning Address → NWC → Manual)

```text
Buyer's order is matched
        │
        ▼
 Has Lightning Address?
   ┌────┴────┐
   Yes       No
   │         │
   ▼         ▼
 Mostro    NWC connected?
 resolves  ┌────┴────┐
 invoice   Yes       No
 (done!)   │         │
           ▼         ▼
         NWC       Manual
       make_invoice  paste
```

1. **Lightning Address is set** → Mostro daemon resolves the invoice server-side. NWC is not needed. This is handled in `AbstractMostroNotifier` before the user ever reaches the invoice screen.
2. **No Lightning Address, NWC connected** → `AddLightningInvoiceScreen` detects the NWC connection and shows the "Generate with Wallet" button via `NwcInvoiceWidget`.
3. **No Lightning Address, no NWC** → Original manual paste flow via `AddLightningInvoiceWidget`.

### Flow with NWC Connected

1. Buyer creates a buy order or takes a sell order
2. Seller pays the escrow (hold invoice)
3. Mostro asks the buyer for a Lightning invoice (and Lightning Address is not set)
4. `AddLightningInvoiceScreen` detects NWC connection via `nwcProvider`
5. User sees the order details + **"Generate with Wallet"** button
6. On tap → `NwcInvoiceWidget` calls `nwcNotifier.makeInvoice(amount)`
7. Shows animated progress: generating → generated ✅ or failed ❌
8. On success → shows invoice preview + **"Confirm & Submit"** button
9. On confirm → submits the invoice to Mostro and navigates home
10. On failure → shows error + "Retry" button + "Enter manually instead" fallback

### Flow without NWC (unchanged)

If no NWC wallet is connected, the original manual flow is shown: text field where the user pastes an invoice. **No regression** — the NWC feature is purely additive.

### Fallback

If NWC invoice generation fails, the user can tap "Enter manually instead" to switch to the manual input flow within the same screen.

## Architecture

### New Files

```text
lib/shared/widgets/nwc_invoice_widget.dart    # Reusable NWC invoice generation UI
docs/NWC_PHASE4_IMPLEMENTATION.md             # This document
```

### Modified Files

```text
lib/features/order/screens/add_lightning_invoice_screen.dart
  — Added NWC detection and conditional rendering
  — Shows NwcInvoiceWidget when wallet connected, manual flow otherwise
  — Added _manualMode flag for fallback
  — Extracted _submitInvoice() and _cancelOrder() helper methods

lib/features/wallet/providers/nwc_provider.dart
  — Added makeInvoice(amountSats, {description, expiry}) method
  — Converts sats to msats for NWC protocol compliance
  — Auto-refreshes balance after invoice creation

lib/l10n/intl_en.arb, intl_es.arb, intl_it.arb
  — Added 8 NWC invoice generation localization strings

lib/generated/l10n.dart, l10n_en.dart, l10n_es.dart, l10n_it.dart
  — Added generated getters for new localization strings
```

## Key Components

### NwcInvoiceWidget (`lib/shared/widgets/nwc_invoice_widget.dart`)

A self-contained `ConsumerStatefulWidget` that handles the full NWC invoice generation lifecycle:

**States:**
- `idle` — Shows "Generate with Wallet" button with amount info
- `generating` — Animated spinner with "Generating invoice..." message
- `generated` — Green checkmark with invoice preview + "Confirm & Submit" button
- `failed` — Error message + retry button + manual fallback link

**Features:**
- Generates invoice with `Mostro order <orderId>` description for traceability
- Shows truncated invoice preview (first 20 + last 20 chars) for user verification
- Handles all NWC error codes with user-friendly messages
- Retry button resets to idle state for another attempt
- "Enter manually instead" button triggers fallback callback

**Design:** Follows the same pattern as `NwcPaymentWidget` (Phase 3) for consistency. Both are reusable shared widgets with similar state machines.

### NwcNotifier.makeInvoice()

New method on the NWC provider:

```dart
Future<TransactionResult> makeInvoice(
  int amountSats, {
  String? description,
  int? expiry,
}) async {
  // Validates connection, converts sats→msats, calls client.makeInvoice()
  // Refreshes balance after successful creation
}
```

- Takes amount in **satoshis** (converts to msats internally for NWC protocol)
- Throws typed exceptions (`NwcResponseException`, `NwcTimeoutException`)
- Auto-refreshes wallet balance after successful invoice creation
- Balance refresh failure is logged but doesn't break the result

### AddLightningInvoiceScreen Changes

The screen now:
1. Watches `nwcProvider` state
2. If connected + not in manual mode + amount > 0 → shows `NwcInvoiceWidget`
3. If disconnected or manual mode → shows original `AddLightningInvoiceWidget`
4. Cancel button always available in both modes
5. Shared `_submitInvoice()` method used by both NWC and manual flows

## Localization

Added 8 new strings in EN, ES, IT:

| Key | EN | ES | IT |
|-----|----|----|-----|
| nwcGenerateWithWallet | Generate with Wallet | Generar con Billetera | Genera con Portafoglio |
| nwcInvoiceGenerating | Generating invoice... | Generando factura... | Generazione fattura... |
| nwcInvoiceGenerated | Invoice Generated! | ¡Factura Generada! | Fattura Generata! |
| nwcInvoiceFailed | Invoice generation failed... | La generación falló... | Generazione fallita... |
| nwcInvoiceTimeout | Invoice generation timed out... | La generación expiró... | Generazione scaduta... |
| nwcConfirmInvoice | Confirm & Submit | Confirmar y Enviar | Conferma e Invia |
| nwcRetryInvoice | Retry | Reintentar | Riprova |
| nwcEnterManually | Enter manually instead | Ingresar manualmente | Inserisci manualmente |

## Edge Cases Handled

1. **NWC disconnects during generation** → Timeout after 30s → error state → retry/manual fallback
2. **Amount is 0 or unknown** → Falls back to manual flow (can't generate invoice without amount)
3. **Wallet returns empty invoice** → Treated as error → retry/manual fallback
4. **Lightning Address already set** → NWC flow never reached (handled upstream in `AbstractMostroNotifier`)
5. **Payment failed status** → Manual input forced (handled upstream in `AbstractMostroNotifier`)
6. **User wants manual control** → "Enter manually instead" always available after failed generation

## Relationship with Lightning Address

Lightning Address takes precedence over NWC for invoice generation because:
- Zero interaction required (fully automatic, server-side)
- Already handled before reaching `AddLightningInvoiceScreen`

NWC `make_invoice` serves as the **middle ground** between Lightning Address (fully automatic) and manual paste (fully manual). It requires one tap to generate + one tap to confirm.

## What's Next (Phase 5+)

- **Phase 5**: Payment notifications (kind 23197 events)
- Future: Consider NWC as fallback when Lightning Address resolution fails

## References

- [Phase 1: Core Library](NWC_PHASE1_IMPLEMENTATION.md)
- [Phase 2: Wallet Management UI](NWC_PHASE2_IMPLEMENTATION.md)
- [Phase 3: Automatic Hold Invoice Payment](NWC_PHASE3_IMPLEMENTATION.md)
- [NIP-47: make_invoice](https://github.com/nostr-protocol/nips/blob/master/47.md#make_invoice)
- [Issue #459](https://github.com/MostroP2P/mobile/issues/459)
