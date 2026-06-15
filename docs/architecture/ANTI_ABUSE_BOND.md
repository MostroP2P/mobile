# Anti-Abuse Bond 

How the Mostro Mobile app participates in the **anti-abuse bond** feature.

> **Scope.** The bond is a **daemon** feature. The economics, the slash
> decisions, the hold-invoice custody, the payout scheduler and the dispute
> mechanics all live in `mostrod`. This document describes only what the
> **client** does: how it discovers a node's bond policy, the wire messages it
> reacts to, the screens it shows, and the session/restore handling it needs to
> get right. For protocol-level details consult the official source:
>
> - **Protocol docs**: https://mostro.network/protocol/
> - **Daemon repo**: https://github.com/MostroP2P/mostro

---

## 1. Overview

An anti-abuse bond is a **second Lightning hold invoice** — separate from the
trade escrow — that a node may require a user to lock when entering a trade. It
deters griefing: a user who abandons or sabotages a trade can have the bond
**slashed**; an honest user always gets it **released**.

The feature is **opt-in and off-by-default at the node level**. A node that does
not enable it produces zero behaviour change in the app. Because the policy
varies per node, the client must:

1. **Discover** whether the connected node enforces bonds, and on which side
   (§2).
2. **React** to the bond wire messages when they arrive (§3–§7).
3. **Manage sessions and restore** so a trailing slash notice is never lost
   (§8).

The app never *decides* anything about a bond — it only renders what the daemon
instructs and submits what the user provides. The daemon is the sole authority
on locking, releasing, slashing and paying out.

### What the client implements

| Concern | Where |
|---------|-------|
| 5 wire actions | `lib/data/models/enums/action.dart:6-10` |
| `waiting-taker-bond` status | `lib/data/models/enums/status.dart:15` |
| Node policy model + parsing | `lib/features/mostro/mostro_instance.dart` |
| Payout request payload | `lib/data/models/bond_payout_request.dart` |
| Pure payout-phase helpers | `lib/shared/utils/bond_payout_helpers.dart` |
| Pure cancel-lifecycle helpers | `lib/shared/utils/bond_cancel_helpers.dart` |
| Message handling / session logic | `lib/features/order/notifiers/abstract_mostro_notifier.dart` |
| Maker-bond create flow | `lib/features/order/notifiers/add_order_notifier.dart` |
| Pay-bond screen | `lib/features/order/screens/pay_bond_invoice_screen.dart` |
| Payout-claim screen | `lib/features/order/screens/bond_payout_invoice_screen.dart` |
| Routes | `lib/core/app_routes.dart:291,302` |

---

## 2. Discovering the node's bond policy

A node advertises its bond policy in its kind-38385 info event. The client
parses those tags into `MostroInstance`
(`lib/features/mostro/mostro_instance.dart`).

### Three-state policy

`BondPolicy` (`mostro_instance.dart:13`) deliberately has **three** states, not
a boolean, so the app can tell "feature off" apart from "old daemon":

| State | Meaning | Source |
|-------|---------|--------|
| `unsupported` | `bond_enabled` tag absent → legacy daemon | `mostro_instance.dart:180-190` |
| `disabled` | `bond_enabled="false"` → operator left it off | |
| `enabled` | `bond_enabled="true"` → bond active, other tags present | |

An empty or whitespace-only `bond_enabled=""` is treated as **missing**
(`unsupported`), not `disabled` — see `_getOptionalTagValue`
(`mostro_instance.dart:137-145`). Malformed values fall back to `unsupported`
defensively, so a corrupt payload can never masquerade as an intentional policy.

### The seven tags

| Tag | Field | Notes |
|-----|-------|-------|
| `bond_enabled` | `bondPolicy` | always emitted on modern daemons |
| `bond_apply_to` | `bondApplyTo` | `take` \| `make` \| `both` (`BondApplyTo`, line 16) |
| `bond_slash_on_waiting_timeout` | `bondSlashOnWaitingTimeout` | node policy: can a timeout slash? |
| `bond_amount_pct` | `bondAmountPct` | validated to `[0.0, 1.0]` |
| `bond_base_amount_sats` | `bondBaseAmountSats` | floor in sats, `>= 0` |
| `bond_slash_node_share_pct` | `bondSlashNodeSharePct` | node's share of a slash, `[0.0, 1.0]` |
| `bond_payout_claim_window_days` | `bondPayoutClaimWindowDays` | days to claim before forfeit, `> 0` |

The six parameter fields are non-null **only** when `bondPolicy == enabled`
(`mostro_instance.dart:44-52`); each getter validates its range and yields
`null` on out-of-range or unparseable input (`mostro_instance.dart:192-250`).

`bondPayoutClaimWindowDays` is the most load-bearing one for the client: it is
how the app computes the forfeit deadline locally (§6). When a node does not
advertise it, the app defaults to **15 days** at every call site (e.g.
`abstract_mostro_notifier.dart:344`, `trades_list_item.dart:37`).

The bond amount itself (`max(amount_pct * order, base_amount_sats)`) is never
computed by the client for charging — the daemon always sends the exact bolt11.
The pct/base tags exist so the UI can *warn the user up front* what a trade on
this node will cost.

---

## 3. The wire contract

Five `Action` values carry the entire client-visible bond protocol
(`lib/data/models/enums/action.dart:6-10`). This table is the canonical
reference — keep `action.dart` in sync with it.

| Action | Direction | Payload | App reaction |
|--------|-----------|---------|--------------|
| `pay-bond-invoice` | Mostro → user | `PaymentRequest` (bolt11) | Show pay-bond screen (§4, §5) |
| `add-bond-invoice` | Mostro → winner | `BondPayoutRequest` | Show payout-claim screen (§6) |
| `bond-invoice-accepted` | Mostro → winner | `Order` (null status) | Mark payout "in progress" (§6) |
| `bond-payout-completed` | Mostro → winner | `Order` (null status) | Mark payout done (§6) |
| `bond-slashed` | Mostro → slashed user | `Order` (bond amount, null status) | Forfeiture dialog (§7) |

Two directions are deliberately distinct: `pay-bond-invoice` (Mostro asks the
user to **pay** a bolt11) versus `add-bond-invoice` (Mostro asks the winner to
**provide** a payout bolt11). They never share a code path.

> **Note on Phase 2 (`BondResolution`).** The solver-directed dispute slash is
> a **daemon-internal** decision. The client never sees it: the loser receives a
> normal `admin-canceled` / `admin-settled` with `payload: null`, and the slash
> surfaces indirectly later — either as an `add-bond-invoice` to the winner or a
> `bond-slashed` notice to the loser. There is no slash-specific wire signal on
> the trade resolution itself.

---

## 4. Flow 1 — Taker pays a bond

When `apply_to ∈ {take, both}` and the taker takes an order, the daemon parks
the order at `waiting-taker-bond` and sends the taker a `pay-bond-invoice`.

```
take-buy / take-sell
        │
        ▼
Mostro:  order → waiting-taker-bond,  pay-bond-invoice (bond bolt11)
        │
        ▼
App:  status → Status.waitingTakerBond   (order_state.dart:282-283)
      navigate → /pay_bond/:orderId        (abstract_mostro_notifier.dart:322-324)
        │
   user pays bond HTLC
        │
        ▼
Mostro:  bond Locked → trade flow continues (pay-invoice / add-invoice)
```

- **Status mapping.** `pay-bond-invoice` resolves the tracked order to
  `Status.waitingTakerBond` (`order_state.dart:282-283`); the transition tables
  whitelist it at `order_state.dart:407` and `:557`. The order's *public*
  NIP-69 bucket stays `pending` on the daemon side, so the order is still
  visible/takeable to others — the app does not hide it.
- **Navigation.** The handler routes to `/pay_bond/:orderId`
  (`abstract_mostro_notifier.dart:322-324`; route at `app_routes.dart:291`).
  The screen (`pay_bond_invoice_screen.dart`) renders the QR/bolt11 and lets the
  user cancel out of the bond window.
- **Restore.** On restart, an order rebuilt as `Status.waitingTakerBond` maps
  back to `Action.payBondInvoice` so the user lands on the pay-bond screen
  again (`restore_manager.dart:508-510`).
- **Seller-as-taker.** When the taker is the *seller* (a buy-order taken), the
  daemon sends two sequential messages on the same order: `pay-bond-invoice`
  first, then the trade hold invoice as `pay-invoice` once the bond locks. The
  client dispatches on **action type** — no bolt11 memo parsing needed.

The taker bond UI label in My Trades comes from `statusWaitingTakerBond`
(`trades_list_item.dart:259-263`).

---

## 5. Flow 2 — Maker pays a bond on order creation

When `apply_to ∈ {make, both}`, the daemon requests a bond from the **maker**
*before* the order is published to Nostr. This flow is driven by
`AddOrderNotifier` (`add_order_notifier.dart`) rather than `OrderNotifier`,
because the order does not exist publicly yet.

Crucially, the client does **not** use a dedicated `waiting-maker-bond` status.
The maker side reuses `pay-bond-invoice` and tracks the limbo with an ephemeral
session flag.

```
submit new-order
        │
        ▼
Mostro:  order parked (WaitingMakerBond, daemon-side),
         pay-bond-invoice (PaymentRequest) on the create requestId
        │
        ▼
App:  _handleMakerBondInvoice           (add_order_notifier.dart:91-100)
        session.bondPending = true
        registerSessionInMemory(session)   ← in-memory only, NOT persisted
        navigate → /pay_bond/:orderId
        │
   maker pays bond HTLC
        │
        ▼
Mostro:  bond Locked → order published → new-order ack on same requestId
        │
        ▼
App:  _confirmOrder                     (add_order_notifier.dart:76-77)
        session.bondPending = false
        saveSession(session)               ← now persisted for real
        navigate → /order_confirmed/:orderId
```

- **`session.bondPending`** (`session.dart:27-29`) marks a maker order stuck in
  bond limbo. While `true`, the session is **in memory only** so an abandoned,
  never-paid order never survives a restart. The shared `pay-bond-invoice`
  handler skips persistence in this state
  (`abstract_mostro_notifier.dart:326-339`).
- **Same `requestId`.** Both the bond bolt11 and the publication ack return on
  the create `requestId`, so `AddOrderNotifier` stays alive until the bond locks
  (`add_order_notifier.dart:37-39`, `:91-100`).
- **Abandoning a maker bond.** The daemon rejects an explicit `cancel` while the
  order sits at `WaitingMakerBond`. So the client abandons **locally** instead:
  if `bondPending == true`, `cancelOrder` drops the in-memory session and lets
  the server-side hold invoice expire (`order_notifier.dart:159-172`). Commits
  `09a80aa7`/`91923f6d` cover this.

---

## 6. Flow 3 — Claiming a slashed bond's share

When a bond is slashed (by solver directive or timeout), the daemon settles the
HTLC immediately and then asks the **winning counterparty** for a payout bolt11
so it can forward their share. This is the only bond flow with a multi-step
state machine on the client, modelled by `BondPayoutPhase`
(`bond_payout_helpers.dart:4-22`).

```
add-bond-invoice (BondPayoutRequest { order, slashed_at })
        │
        ▼
App:  expiry check against claim window      (abstract_mostro_notifier.dart:340-347)
      if not expired → navigate /bond_payout/:orderId
        │
   user submits payout bolt11
        │  sendBondPayoutInvoice  (order_notifier.dart:141 → mostro_service.dart:239)
        ▼
Mostro:  bond-invoice-accepted  → phase: acknowledged
        │
        ▼
Mostro:  bond-payout-completed  → phase: completed
```

### Phase model

`bondPayoutPhase(messages)` (`bond_payout_helpers.dart:55`) reduces the message
history to the current phase — **latest message by timestamp wins**:

| Phase | Latest bond message | UI |
|-------|--------------------|----|
| `none` | no bond-payout messages | — |
| `pending` | inbound `add-bond-invoice` (`BondPayoutRequest`) | claim form + deadline |
| `acknowledged` | `bond-invoice-accepted` | "in progress", form hidden |
| `completed` | `bond-payout-completed` | done, single CLOSE button |

An **outbound** `add-bond-invoice` (the user's own `PaymentRequest` reply) does
not define a phase — the helper skips it and keeps looking
(`bond_payout_helpers.dart:42-48`, `:72-78`). This lets retries and
acknowledgements interleave correctly.

### Deadline anchored on `slashed_at`

`BondPayoutRequest` (`bond_payout_request.dart`) carries `slashed_at`, the fixed
slash timestamp. The client computes the forfeit deadline **from that anchor**,
never from message receipt time — so a recipient who was offline for days still
sees the true deadline:

- `bondClaimDeadline(slashedAt, claimWindowDays)` — `bond_payout_helpers.dart:24`
- `isBondClaimExpired(...)` — `:31`
- `hasPendingBondClaim(...)` — `:89` (gates the badge and the CLAIM button)

`claimWindowDays` comes from `instance.bondPayoutClaimWindowDays`, defaulting to
**15** when absent. An already-expired request is dropped without navigating
(`abstract_mostro_notifier.dart:344-345`).

### Where it surfaces

- **My Trades badge** (`trades_list_item.dart:38-44`): `bondPayoutBadge`
  ("PAYOUT PENDING") while `hasPendingBondClaim`, `bondPayoutInProgressBadge`
  ("PAYOUT IN PROGRESS") while `acknowledged`.
- **Trade Details CLAIM button** (`trade_detail_screen.dart:270-287`, `:847-848`):
  shown only while `hasPendingBondClaim`; pushes `/bond_payout/:orderId`.
- **Claim screen** (`bond_payout_invoice_screen.dart`): on `acknowledged` /
  `completed` it hides the form and shows an info message + a single CLOSE
  button (`:48-59`, button key `bondPayoutCloseButton` `:240-251`); the deadline
  is formatted via `DateFormat.yMMMd().add_jm()` (`:87-95`).
- **Message detail copy** (`mostro_message_detail_widget.dart:70-90`, `:295-311`):
  renders the bond amount and per-phase prose; on `completed` it restores the
  underlying trade action's message (`_previousNonBondAction`, `:90-99`).

### Submission error handling

`OrderNotifier.sendBondPayoutInvoice` (`order_notifier.dart:141-152`) publishes
**then** persists, and lets persistence errors propagate so the claim screen's
catch keeps the user on the form rather than silently losing the submission
(commit `f57c075a`).

---

## 7. Forfeiture notice (`bond-slashed`)

`bond-slashed` is a **best-effort** notice the daemon sends to a taker whose
bond was slashed on a **waiting-state timeout** (it complements the
`Action::Canceled` the user already gets for the order). It is *not* sent on a
voluntary cancel — that returns the bond.

- **Payload.** `Order` (a `SmallOrder`) whose `amount` is the **slashed bond
  amount**, not the trade amount, and whose `status` is `null`.
- **Ordering.** The daemon sends `canceled` first, then `bond-slashed` ~150 ms
  later, both to the same trade pubkey. This ordering is why the client must
  defer session deletion (§8).
- **Why it was being dropped before.** Two bugs, both fixed: (1) the action was
  not in the enum, so `MostroMessage.fromJson` threw and discarded it; (2) the
  `canceled` handler deleted the session immediately, dropping the trade key
  from the subscription filter and the decryption key, so the trailing notice
  could never be received or decrypted.

### Rendering

- **Extraction** (`notification_data_extractor.dart:222-232`): pulls
  `{amount, order_id, fiat_code, fiat_amount, payment_method}` from the payload
  and persists a non-temporary notification. The other payout acks
  (`add-bond-invoice`, `bond-invoice-accepted`, `bond-payout-completed`) return
  `null` here — no notification (`:217-219`).
- **Mapping** (`notification.dart:87`): `bond-slashed` →
  `NotificationType.cancellation`. List preview uses the short
  `notification_bond_slashed_title` / `_message` keys
  (`notification_message_mapper.dart:102,219`).
- **Tap → detail dialog** (`notification_item.dart:139-140`, `:171-215`):
  `_showBondSlashedDialog` shows the forfeiture detail in **prose**
  (`notification_bond_slashed_detail`, parameterized with
  amount/orderId/fiatAmount/fiatCode/paymentMethod) with a **green** close
  button (`AppTheme.activeColor`). The `bond-slashed` case is isolated from the
  no-op action group in the switch to avoid fall-through (commit `b226af3c`).

---

## 8. Session lifecycle & restart resilience

This is the subtlest part of the client. Because `bond-slashed` arrives *after*
`canceled`, deleting the session on `canceled` would drop the keys needed to
receive the trailing notice. But deferring deletion for *every* cancel would
strand sessions for ordinary voluntary cancels. The rule:

> **Defer deletion only for a bonded order the user did NOT cancel itself.**
> A voluntary cancel returns the bond (no slash, no notice); a non-bonded order
> is never slashed.

Encoded as a pure helper:

```dart
// bond_cancel_helpers.dart:14
bool shouldDeferBondCancelDeletion({userInitiated, hadBond}) =>
    !userInitiated && hadBond;
```

### The three signals

| Signal | Where | Purpose |
|--------|-------|---------|
| `_userInitiatedCancels` (Set) | `abstract_mostro_notifier.dart:41` | marks a cancel the user triggered |
| `_orderHadBond(orderId)` | `:784` | true if a `pay-bond-invoice` exists in storage |
| `_bondCancelDeletionTimers` (Map) | `:33` | the 60 s deferral timers |

`OrderNotifier.cancelOrder` calls `markUserInitiatedCancel` after a successful
send (`order_notifier.dart:172`). This flag is **deliberately not persisted** —
`Action.cancel` already maps to `Status.canceled` in `_resolveStatus`, so
persisting an outbound marker would corrupt the rebuilt state on a rejected or
cooperative cancel. The restart case is covered by reconciliation instead.

### Live `canceled` handler

`abstract_mostro_notifier.dart:238-252`:

- `userInitiated || !hadBond` → delete the session **immediately** (old
  behaviour).
- bonded + not user-initiated (the real timeout-slash case) → start a **60 s**
  deferral timer (`_startBondCancelDeletion`, `:799`;
  `_bondCancelGraceWindow = 60s`, `:813`).

The `bond-slashed` handler (`:268-274`) cancels that timer and deletes the
session once the notice lands. Out-of-order safe: if `bond-slashed` arrives
first, the later `canceled` finds no session and no-ops.

### Restart reconciliation

The 60 s timer is in-memory and lost if the app closes inside the window. On
restart, `OrderNotifier.sync()` calls `reconcileCanceledBondedSession()`
(`order_notifier.dart:70-74` → `abstract_mostro_notifier.dart:833`) for any
order rebuilt as `canceled`. The decision is a pure helper
(`reconcileBondCancelAction`, `bond_cancel_helpers.dart:37`):

| Condition | Action |
|-----------|--------|
| no session, no bond, or a live timer already owns it | `none` |
| `bond-slashed` already received, no cancel timestamp, or window elapsed | `deleteNow` |
| window not yet elapsed | `rearm` (re-arm the timer for the remainder) |

### Retake guard

If the user retakes the same `orderId` within the 60 s window, a stale grace
timer (live or reconcile-rearmed) must not delete the fresh session.
`clearBondCancelDeletion(orderId)` (`abstract_mostro_notifier.dart:819`) cancels
the timer and clears the user-cancel flag; it is called from
`takeSellOrder` / `takeBuyOrder` right after `newSession`
(`order_notifier.dart:97`, `:118`).

---

## 9. Guarding the tracked order in `order_state.dart`

The bond payout acks and the slash notice all carry a `SmallOrder` with a
**null status** and a **bond-sized amount**. If `OrderState` let that overwrite
the tracked trade order, My Trades would show the bond amount and lose the real
trade status. The guard (`order_state.dart:243-253`):

```dart
final bool isBondPayoutAck =
    message.action == Action.bondInvoiceAccepted ||
    message.action == Action.bondPayoutCompleted ||
    message.action == Action.bondSlashed;

order: (message.payload is Order && !isBondPayoutAck) ? ... : <keep current>
```

Correspondingly, `_resolveStatus` returns the **current** status unchanged for
`add-bond-invoice` (`:372`) and for the three acks (`:377-379`), so an ack never
moves the order out of its real trade state. Only `pay-bond-invoice` actually
sets a status (`waiting-taker-bond`, `:282-283`).

---

## 10. Notifications wiring (current state)

Bond actions are wired into the in-app notification surfaces for
compiler-exhaustiveness and, for `bond-slashed`, full rendering (§7). The payout
acks are intentionally **no-op** in the notification list today
(`notification_data_extractor.dart:217-219`); only `bond-slashed` produces a
persisted notification. **Push notifications for bond actions are not yet
wired** — this is a known gap (§12).

When push/tap handling for `add-bond-invoice` is added, it must route to
`/bond_payout/:orderId`, not the trade detail screen.

---

## 11. Testing

All bond tests are **pure** (no `mocks.mocks.dart` import) and run locally even
when generated mocks are stale:

| File | Covers |
|------|--------|
| `test/shared/utils/bond_payout_helpers_test.dart` | phase model, deadline, expiry, `hasPendingBondClaim` |
| `test/shared/utils/bond_cancel_helpers_test.dart` | defer/reconcile truth tables, window boundary |
| `test/features/order/models/order_state_bond_slashed_test.dart` | slash notice must not overwrite the tracked order |
| `test/features/order/models/order_state_maker_bond_test.dart` | maker bond status handling |
| `test/features/order/notifiers/maker_bond_timeout_test.dart` | maker-bond flow disarms the create timeout |
| `test/features/notifications/widgets/notification_item_tap_test.dart` | slash dialog dispatch / switch fall-through guard |
| `test/data/models/session_bond_pending_test.dart` | `bondPending` ephemeral session |
| `test/features/mostro/mostro_instance_test.dart` | bond-tag parsing / validation |

> Pure helpers were chosen because `MockSessionNotifier` overrides
> `getSessionByOrderId` / `sessions` with fixed fields and bypasses the real
> session map, which makes `deleteSession`-wiring assertions fragile. The
> decision logic was extracted into `bond_payout_helpers.dart` /
> `bond_cancel_helpers.dart` so the truth tables can be tested without mocks.

---

## 12. Known limitations / open items

- **Push notifications** for bond actions are no-op; only in-app surfaces work.
- **Anti-spam dedup** of daemon retries: dedup keys include the message
  timestamp, so each `add-bond-invoice` retry is treated as new.
- **Real-time deadline countdown**: the forfeit deadline is computed at screen
  open, not refreshed live.
- **Offline correctness** of the 60 s deferral depends on relay retention of the
  trailing `bond-slashed` gift wrap.

---

**Last Updated**: 2026-06-15
**Related docs**: `MULTI_MOSTRO_SUPPORT.md` (info-event parsing),
`ORDER_STATUS_HANDLING.md` (status model),
`TIMEOUT_DETECTION_AND_SESSION_CLEANUP.md` (session cleanup),
`SESSION_RECOVERY_ARCHITECTURE.md` (restore).
