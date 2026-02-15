# Lightning Address Confirmation UX

## Overview

This document describes the confirmation step added before the app uses a
configured Lightning Address to receive sats on behalf of the user. The change
was introduced to address [issue #474](https://github.com/MostroP2P/mobile/issues/474).

## Problem

Previously, when a buyer took a sell order and had a Lightning Address
configured in settings, the app **silently sent** the address to Mostro without
any user interaction. The buyer went directly from taking the order to seeing an
active order with no feedback about what happened.

This contrasted with both the NWC and manual invoice flows, which require
explicit user interaction before submitting payment information.

## Solution

An intermediate confirmation screen now appears whenever a Lightning Address
would be used automatically. The screen shows:

1. **Header text** — explains that the Lightning Address will be used for this
   order.
2. **Address display** — the full Lightning Address in a highlighted box so the
   user can verify it.
3. **"Use This Address" button** — primary action that sends the address to
   Mostro.
4. **"Enter invoice manually" link** — secondary action that falls back to the
   existing manual invoice input flow.
5. **Cancel button** — cancels the order entirely.

### Flow

```text
Buyer takes sell order
  → App detects configured Lightning Address
    → Navigates to invoice screen with lnAddress query parameter
      → User sees confirmation widget
        → "Use This Address" → sends LN address to Mostro → order active
        → "Enter invoice manually" → shows manual invoice input
        → "Cancel" → cancels the order
```

## Unified UX Pattern

After this change, all three receiving methods follow the same confirm-then-send
pattern:

| Method           | Step 1                  | Step 2            | Step 3              |
|------------------|------------------------|-------------------|---------------------|
| Lightning Address | Show address to confirm | User confirms     | App sends to Mostro |
| NWC              | Show "Generate Invoice" | User generates    | App sends to Mostro |
| Manual           | Show invoice input      | User pastes       | App sends to Mostro |

## Files Changed

| File | Change |
|------|--------|
| `lib/shared/widgets/ln_address_confirmation_widget.dart` | New widget — displays address and confirm/fallback buttons |
| `lib/features/order/screens/add_lightning_invoice_screen.dart` | Shows LN address confirmation when `lnAddress` param present |
| `lib/features/order/notfiers/abstract_mostro_notifier.dart` | Navigates to confirmation screen instead of auto-sending |
| `lib/core/app_routes.dart` | Passes `lnAddress` query parameter to the screen |
| `lib/l10n/intl_en.arb` | English localization strings |
| `lib/l10n/intl_es.arb` | Spanish localization strings |
| `lib/l10n/intl_it.arb` | Italian localization strings |

## Localization Keys

| Key | EN | ES | IT |
|-----|----|----|-----|
| `lnAddressConfirmTitle` | Receiving sats via Lightning Address | Recibiendo sats vía Lightning Address | Ricezione sats tramite Lightning Address |
| `lnAddressConfirmDescription` | Your Lightning Address will be used… | Tu Lightning Address será utilizada… | Il tuo Lightning Address verrà utilizzato… |
| `lnAddressConfirmButton` | Use This Address | Usar esta dirección | Usa questo indirizzo |
| `lnAddressEnterManually` | Enter invoice manually | Ingresar factura manualmente | Inserisci fattura manualmente |
| `lnAddressConfirmHeader` | Your Lightning Address will be used… (with orderId) | Tu Lightning Address será utilizada… | Il tuo Lightning Address verrà utilizzato… |

## Design Decisions

- **Visual consistency**: The confirmation widget reuses the same visual
  patterns as `NwcInvoiceWidget` — same border styles, color scheme, button
  layout, and icon usage.
- **Priority order preserved**: Lightning Address → NWC → Manual. If both LN
  address and NWC are available, LN address confirmation takes priority (NWC is
  still accessible via manual fallback).
- **Payment-failed bypass**: When a payment failure triggers a new add-invoice
  event, the app skips the LN address confirmation and goes straight to manual
  input, since the address likely caused the failure.
