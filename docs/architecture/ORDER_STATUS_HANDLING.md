# Order Status Handling

This document describes how the mobile app processes, maps, and displays order statuses received from the Mostro daemon. It covers the action-to-status mapping, role-specific behavior, the restore flow, and UI presentation.

## Overview

The Mostro daemon communicates with the app via encrypted gift wrap messages (NIP-59). Each message contains an **action** that describes what happened. The app maps these actions to internal **status** values that determine what the user sees and what operations are available.

The key files involved are:

- `lib/data/models/enums/status.dart` — Status enum definition
- `lib/data/models/enums/action.dart` — Action enum definition
- `lib/features/order/models/order_state.dart` — Action-to-status mapping (`_getStatusFromAction`)
- `lib/features/restore/restore_manager.dart` — Status-to-action mapping for restore (`_getActionFromStatus`)
- `lib/features/trades/widgets/mostro_message_detail_widget.dart` — Order Details display
- `lib/features/trades/widgets/trades_list_item.dart` — My Trades list chips

## Status Enum

The app defines the following statuses:

| Status | Protocol Value | Description |
|---|---|---|
| `pending` | `pending` | Order published, waiting for a counterpart |
| `waitingBuyerInvoice` | `waiting-buyer-invoice` | Waiting for the buyer to provide a Lightning invoice |
| `waitingPayment` | `waiting-payment` | Waiting for the seller to pay the hold invoice |
| `active` | `active` | Both parties matched, trade in progress |
| `fiatSent` | `fiat-sent` | Buyer confirmed fiat payment sent |
| `settledHoldInvoice` | `settled-hold-invoice` | Seller released, Lightning payment to buyer in progress |
| `success` | `success` | Trade completed successfully |
| `paymentFailed` | `payment-failed` | Lightning payment to buyer failed |
| `canceled` | `canceled` | Order canceled (timeout, direct, or hold invoice canceled) |
| `cooperativelyCanceled` | `cooperatively-canceled` | Cooperative cancellation in progress or completed |
| `canceledByAdmin` | `canceled-by-admin` | Admin canceled the order during a dispute |
| `settledByAdmin` | `settled-by-admin` | Admin resolved a dispute by releasing sats |
| `completedByAdmin` | `completed-by-admin` | Reserved status, not actively used |
| `dispute` | `dispute` | Order is under dispute |
| `expired` | `expired` | Order expired, treated as canceled |
| `inProgress` | `in-progress` | Internal status used during restore |

## Action-to-Status Mapping

When the app receives a gift wrap message from Mostro, `_getStatusFromAction()` in `order_state.dart` determines the new status. This mapping is action-driven, not role-specific — role differentiation happens naturally because Mostro sends different actions to buyer and seller.

### Waiting Payment

| Action | Status | When |
|---|---|---|
| `waitingSellerToPay` | `waitingPayment` | Seller must pay the hold invoice |
| `payInvoice` | `waitingPayment` | Seller receives the invoice to pay |
| `takeSell` | `waitingPayment` | Seller takes a buy order |

### Waiting Buyer Invoice

| Action | Status | When |
|---|---|---|
| `waitingBuyerInvoice` | `waitingBuyerInvoice` | Buyer must provide a Lightning invoice |
| `addInvoice` | `waitingBuyerInvoice` | Buyer receives request to add invoice (unless in paymentFailed state) |
| `takeBuy` | `waitingBuyerInvoice` | Buyer takes a sell order |

### Active

| Action | Status | When |
|---|---|---|
| `buyerTookOrder` | `active` | Seller is notified a buyer took their order |
| `holdInvoicePaymentAccepted` | `active` | Buyer is notified the seller paid the hold invoice |
| `buyerInvoiceAccepted` | `active` | Buyer's invoice was accepted |

### Fiat Sent

| Action | Status | When |
|---|---|---|
| `fiatSent` | `fiatSent` | Buyer confirms fiat payment |
| `fiatSentOk` | `fiatSent` | Counterpart is notified fiat was sent |

### Settled Hold Invoice (Intermediate)

| Action | Status | When |
|---|---|---|
| `released` | `settledHoldInvoice` | **Buyer** receives this when seller releases sats |
| `release` | `settledHoldInvoice` | Seller initiates release |

This is an intermediate status for the **buyer only**. It means the seller released the sats and the Lightning payment to the buyer is in progress but not yet confirmed. The seller never sees this status because they receive `holdInvoicePaymentSettled` instead, which maps directly to `success`.

### Success

| Action | Status | When |
|---|---|---|
| `purchaseCompleted` | `success` | Buyer receives confirmation that the LN payment completed |
| `holdInvoicePaymentSettled` | `success` | **Seller** receives this when the hold invoice settles |
| `rate` | `success` | User receives a rating prompt |
| `rateReceived` | `success` | Rating confirmation received |

### Payment Failed

| Action | Status | When |
|---|---|---|
| `paymentFailed` | `paymentFailed` | Lightning payment to buyer failed |

When `addInvoice` is received while in `paymentFailed` status, the status is preserved (stays `paymentFailed`) for UI consistency, so the user sees the payment failed context while providing a new invoice.

### Canceled

| Action | Status | When |
|---|---|---|
| `canceled` | `canceled` | Mostro cancels the order (timeout, explicit) |
| `cancel` | `canceled` | Cancel action initiated |
| `cooperativeCancelAccepted` | `canceled` | Both parties accepted cooperative cancellation |
| `holdInvoicePaymentCanceled` | `canceled` | Hold invoice was canceled |
| `adminCanceled` | `canceled` | Admin canceled the order |
| `adminCancel` | `canceled` | Admin cancel action |

### Cooperative Cancellation

| Action | Status | When |
|---|---|---|
| `cooperativeCancelInitiatedByYou` | `cooperativelyCanceled` | User initiated cooperative cancellation |
| `cooperativeCancelInitiatedByPeer` | `cooperativelyCanceled` | Counterpart initiated cooperative cancellation |

This is a pending state. Once the other party accepts, the status changes to `canceled` via `cooperativeCancelAccepted`.

### Dispute

| Action | Status | When |
|---|---|---|
| `disputeInitiatedByYou` | `dispute` | User opened a dispute |
| `disputeInitiatedByPeer` | `dispute` | Counterpart opened a dispute |
| `dispute` | `dispute` | General dispute action |
| `adminTakeDispute` | `dispute` | Admin took the dispute |
| `adminTookDispute` | `dispute` | Admin took the dispute (confirmation) |

### Admin Resolution

| Action | Status | When |
|---|---|---|
| `adminSettle` | `settledByAdmin` | Admin resolves dispute by releasing sats to the user |
| `adminSettled` | `settledByAdmin` | Admin settlement confirmation |

### Informational Actions (No Status Change)

These actions preserve the current status:

- `rateUser` — Rate a user
- `invoiceUpdated` — Invoice was updated
- `sendDm` — Direct message
- `tradePubkey` — Trade public key exchange
- `adminAddSolver` — Admin assigned a solver
- `newOrder` — Uses payload status if available

## Role-Specific Behavior

Mostro sends different actions to buyer and seller for the same event. The app does not need role-based logic in `_getStatusFromAction()` because the role differentiation is handled by the protocol itself.

### Seller Releases Sats — What Each Party Sees

```
Seller releases
    │
    ├── Buyer receives: Action.released
    │   └── Status: settledHoldInvoice ("Paying sats")
    │       └── Later: Action.purchaseCompleted → Status: success
    │
    └── Seller receives: Action.holdInvoicePaymentSettled
        └── Status: success (immediately)
```

The seller's part is done when they release, so they see success right away. The buyer must wait for the Lightning payment to actually complete.

### Payment Failure Cycle (Buyer Only)

```
Action.released → settledHoldInvoice ("Paying sats")
    │
    └── LN payment fails
        │
        Action.paymentFailed → paymentFailed ("Payment failed")
            │
            Action.addInvoice → paymentFailed (preserved, buyer adds new invoice)
                │
                └── LN payment retried
                    ├── Success: Action.purchaseCompleted → success
                    └── Fails again: cycle repeats
```

### Buyer Takes a Sell Order

```
Buyer takes sell order
    │
    Action.takeBuy → waitingBuyerInvoice (buyer adds invoice)
        │
        Action.addInvoice → waitingBuyerInvoice
            │
            Action.holdInvoicePaymentAccepted → active (seller paid hold invoice)
                │
                Action.fiatSentOk → fiatSent (buyer confirms fiat payment)
                    │
                    Action.released → settledHoldInvoice (seller releases)
                        │
                        Action.purchaseCompleted → success
```

### Seller Creates a Sell Order

```
Seller creates sell order
    │
    Action.newOrder → pending
        │
        Action.buyerTookOrder → active (a buyer took the order)
            │
            Action.waitingSellerToPay → waitingPayment
                │
                Action.payInvoice → waitingPayment (seller pays hold invoice)
                    │
                    Action.fiatSentOk → fiatSent (buyer confirms fiat)
                        │
                        Action.holdInvoicePaymentSettled → success
```

## Restore Flow

When the app restores sessions after restart, it receives orders with a status but no action. The `_getActionFromStatus()` method in `restore_manager.dart` synthesizes the appropriate action based on the status and the user's role.

| Status | Buyer Action | Seller Action |
|---|---|---|
| `pending` | `newOrder` | `newOrder` |
| `waitingBuyerInvoice` | `addInvoice` | `waitingBuyerInvoice` |
| `waitingPayment` | `waitingSellerToPay` | `payInvoice` |
| `active` | `holdInvoicePaymentAccepted` | `buyerTookOrder` |
| `fiatSent` | `fiatSentOk` | `fiatSentOk` |
| `settledHoldInvoice` | `released` | `holdInvoicePaymentSettled` |
| `success` | `purchaseCompleted` | `purchaseCompleted` |
| `canceled` | `canceled` | `canceled` |
| `canceledByAdmin` | `adminCanceled` | `adminCanceled` |
| `cooperativelyCanceled` | `cooperativeCancelAccepted` | `cooperativeCancelAccepted` |
| `settledByAdmin` | `adminSettled` | `adminSettled` |
| `completedByAdmin` | `adminSettled` | `adminSettled` |
| `dispute` | `disputeInitiatedByPeer` | `disputeInitiatedByPeer` |
| `expired` | `canceled` | `canceled` |
| `paymentFailed` | `paymentFailed` | `paymentFailed` |
| `inProgress` | `buyerTookOrder` | `buyerTookOrder` |

The role differentiation in restore is critical for `settledHoldInvoice`: the buyer sees the intermediate "Paying sats" state, while the seller sees success.

## UI Presentation

Statuses are displayed in two contexts with different levels of detail.

### My Trades List (Short Labels)

The status chips in the trades list use short labels for compact display:

| Status | Label | Color |
|---|---|---|
| `active` | Active | Green |
| `pending` | Pending | Yellow |
| `waitingPayment` | Waiting payment | Orange |
| `waitingBuyerInvoice` | Waiting invoice | Orange |
| `paymentFailed` | Payment Failed | Gray |
| `fiatSent` | Fiat-sent | Green |
| `canceled` | Cancel | Gray |
| `cooperativelyCanceled` | Cancel | Gray |
| `canceledByAdmin` | Cancel | Gray |
| `settledByAdmin` | Settled | Green |
| `settledHoldInvoice` | Paying sats | Yellow |
| `completedByAdmin` | Completed | Green |
| `dispute` | Dispute | Red |
| `expired` | Expired | Gray |
| `success` | Success | Green |

### Order Details (Descriptive Labels)

The Order Details screen shows descriptive, user-friendly labels:

| Status | Label |
|---|---|
| `active` | Active order |
| `pending` | Pending order |
| `waitingPayment` | Waiting for seller payment |
| `waitingBuyerInvoice` | Waiting for buyer invoice |
| `paymentFailed` | Payment failed |
| `fiatSent` | Fiat sent |
| `canceled` | Order canceled |
| `cooperativelyCanceled` | Cooperative cancellation |
| `canceledByAdmin` | Order canceled by an administrator |
| `settledByAdmin` | Sats released by an administrator |
| `settledHoldInvoice` | Paying sats |
| `completedByAdmin` | Sats released by an administrator |
| `dispute` | Order in dispute |
| `expired` | Order expired |
| `success` | Successful order |

All labels are localized in English, Spanish, Italian, and French.

The short labels use keys like `S.of(context)!.active` while the descriptive labels use keys like `S.of(context)!.statusDetailActive`.

## Key Design Decisions

### Why `released` Maps to `settledHoldInvoice` Instead of `success`

When the seller releases sats, the Lightning payment to the buyer has not yet completed. Mapping `released` to `success` gave the buyer a false sense of completion. If the payment subsequently failed, the buyer had already seen "Success" which was incorrect. The intermediate `settledHoldInvoice` status ("Paying sats") accurately reflects the state: sats are being paid but not yet received.

The seller sees `success` immediately because they receive `holdInvoicePaymentSettled`, not `released`. Their part of the trade is complete.

### Why `addInvoice` Preserves `paymentFailed` Status

When a Lightning payment fails, the buyer receives `paymentFailed` followed by `addInvoice` to provide a new invoice. Without preservation, `addInvoice` would change the status to `waitingBuyerInvoice`, losing the payment failure context. By checking the current status, the app keeps `paymentFailed` visible so the UI can show an appropriate message explaining why a new invoice is needed.

### Why Cancellation Types Share the Same Chip Label

In the My Trades list, all cancellation types (`canceled`, `cooperativelyCanceled`, `canceledByAdmin`) display the same short label ("Cancel") because the chip space is limited and the distinction is not critical at a glance. The differentiation is shown in the Order Details screen where there is more space for descriptive text, and in the action text above which provides full context about what happened.
