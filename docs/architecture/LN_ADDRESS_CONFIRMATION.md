# Lightning Address Confirmation UX

## Overview

When a buyer takes a sell order and has a Lightning Address configured in settings, the app shows a confirmation screen before sending the address to Mostro. This prevents the app from silently using the address without user awareness.

## Problem Solved

Previously, the app silently sent the Lightning Address to Mostro with no user interaction. The buyer went from taking an order directly to an active order with no feedback. This contrasted with the NWC and manual invoice flows, which both require explicit user interaction.

## Flow

```text
Buyer takes sell order
  → App detects configured Lightning Address
    → Navigates to invoice screen with lnAddress query parameter
      → User sees confirmation widget
        → "Use This Address" → sends LN address to Mostro → order active
        → "Enter invoice manually" → shows manual invoice input
        → "Cancel" → cancels the order
```

## Unified Payment Reception Pattern

All three receiving methods follow the same confirm-then-send pattern:

| Method           | Step 1                  | Step 2            | Step 3              |
|------------------|------------------------|-------------------|---------------------|
| Lightning Address | Show address to confirm | User confirms     | App sends to Mostro |
| NWC              | Show "Generate Invoice" | User generates    | App sends to Mostro |
| Manual           | Show invoice input      | User pastes       | App sends to Mostro |

## Key Files

| File | Purpose |
|------|--------|
| `lib/shared/widgets/ln_address_confirmation_widget.dart` | Confirmation widget with address display and confirm/fallback buttons |
| `lib/features/order/screens/add_lightning_invoice_screen.dart` | Shows confirmation when `lnAddress` param present |
| `lib/features/order/notfiers/abstract_mostro_notifier.dart` | Navigates to confirmation screen instead of auto-sending |
| `lib/core/app_routes.dart` | Passes `lnAddress` query parameter to the screen |

## Design Decisions

- **Visual consistency**: reuses same visual patterns as `NwcInvoiceWidget` (border styles, color scheme, button layout)
- **Priority preserved**: Lightning Address → NWC → Manual. If both are available, LN address confirmation takes priority
- **Payment-failed bypass**: when a payment failure triggers a new add-invoice event, the app skips confirmation and goes to manual input (the address likely caused the failure)

## References

- [NWC Architecture](NWC_ARCHITECTURE.md) — for understanding the NWC alternative flow
- [Mostro Protocol](https://mostro.network/protocol/) — for the order lifecycle and invoice submission
- [Issue #474](https://github.com/MostroP2P/mobile/issues/474)
