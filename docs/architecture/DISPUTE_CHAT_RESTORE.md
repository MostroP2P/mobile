# Dispute Chat Restore

## Current Implementation

### Overview

When a user restores their wallet from a mnemonic, `RestoreService` reconstructs all active
trading sessions and their associated states — including sessions with open disputes. For
disputed orders, the restore process must also re-enable the dispute chat so the user can
continue communicating with the assigned admin (solver).

### Protocol Flow

```text
User enters mnemonic
        │
        ▼
RestoreService.importMnemonicAndRestore()
        │
        ├─ KeyManager.importMnemonic()   → derives master key
        ├─ KeyManager.init()             → loads keys from storage
        └─ initRestoreProcess()
                │
                ▼
         _clearAll()
          ├─ sessionNotifier.reset()
          ├─ mostroStorage.deleteAll()
          ├─ eventStorage.deleteAll()
          ├─ notificationsRepository.clearAll()
          ├─ invalidate chatRooms providers
          └─ invalidate disputeChat providers (stale subscriptions)
                │
                ▼
         _createTempSubscription()
          └─ kind 1059 filter on tempTradeKey (index 1)
                │
                ▼
         Stage 1 — Action.restore
          ├─ _sendRestoreRequest()
          ├─ _waitForEvent(gettingRestoreData)
          └─ _extractRestoreData()
               → Map<orderId, tradeIndex>
               → List<RestoredDispute>  (includes solverPubkey, disputeId)
                │
                ▼
         Stage 2 — Action.orders
          ├─ _sendOrdersDetailsRequest(orderIds)
          ├─ _waitForEvent(gettingOrdersDetails)
          └─ _extractOrdersDetails()
               → OrdersResponse (full order state per orderId)
                │
                ▼
         Stage 3 — Action.lastTradeIndex
          ├─ _sendLastTradeIndexRequest()
          ├─ _waitForEvent(gettingTradeIndex)
          └─ _extractLastTradeIndex()
               → int lastTradeIndex
                │
                ▼
         _tempSubscription.cancel()
                │
                ▼
         restore(ordersMap, lastTradeIndex, ordersResponse, disputes)
          ├─ keyManager.setCurrentKeyIndex(lastTradeIndex + 1)
          ├─ isRestoringProvider = true   (blocks MostroService._onData processing)
          │
          ├─ FOR EACH order in ordersIds:
          │   ├─ derive tradeKey from tradeIndex
          │   ├─ determine role/peer from buyerTradePubkey / sellerTradePubkey
          │   ├─ find matching RestoredDispute (if any)
          │   ├─ extract solverPubkey from RestoredDispute
          │   ├─ Session(
          │   │    adminPubkey: solverPubkey,   ← enables adminSharedKey computation
          │   │    disputeId: dispute.disputeId
          │   │  )
          │   ├─ sessionNotifier.saveSession(session)
          │   │    └─ triggers SubscriptionManager._updateAllSubscriptions()
          │   │         → relay REQ recreated for this tradeKey
          │   └─ if peer != null: chatRoomsProvider.subscribe()
          │
          ├─ Future.delayed(10 seconds)
          │   └─ relay delivers historical gift-wrap events during this window;
          │      MostroService._onData stores them in mostroStorage but
          │      isRestoringProvider=true blocks state.updateWith()
          │
          ├─ storage.deleteAll()
          │   └─ clears relay-replayed events that arrived during 10s window
          │      (prevents stale events from overwriting restore messages)
          │
          ├─ FOR EACH order in ordersResponse:
          │   ├─ build MostroMessage from OrderDetail + dispute state
          │   ├─ storage.addMessage(key, message)
          │   └─ notifier.updateStateFromMessage(message)
          │
          └─ isRestoringProvider = false
```

### Dispute Chat Subscription During Restore

`DisputeChatNotifier` subscribes to kind 1059 events addressed to the `adminSharedKey` — an
ECDH keypair derived from `tradeKey` and the solver's public key.

For this to work post-restore, `Session.adminSharedKey` must be non-null at the time the
dispute chat provider is first accessed. The restore flow guarantees this by passing
`adminPubkey: solverPubkey` to the `Session` constructor during the session-creation loop.
`Session` computes `adminSharedKey` in its constructor from `tradeKey × adminPubkey`.

`DisputeChatNotifier._subscribe()` checks for `adminSharedKey != null`. If present, it
immediately registers a relay subscription. If absent (e.g. solver not yet assigned), it
calls `_listenForSession()` which watches `sessionNotifierProvider` for the key to appear.

The provider factory auto-calls `unawaited(notifier.initialize())` on first access, so the
subscription begins as soon as any widget or restore code reads the provider.

---

## Known Issues

### Issue 1 — Isolated Subscription Instead of SubscriptionManager

#### Description

`DisputeChatNotifier` creates its own direct relay subscription via
`nostrService.subscribeToEvents(request)` — bypassing `SubscriptionManager`.

An earlier attempt integrated dispute chat subscriptions into `SubscriptionManager` so all
relay REQs are managed centrally. This approach was abandoned because of a critical side
effect: `SubscriptionManager._updateAllSubscriptions()` fires every time any session
changes (including during the restore loop's `saveSession` calls). Adding dispute chat keys
into that path caused `_updateAllSubscriptions` to recreate **all** relay subscriptions on
every `saveSession` iteration — including subscriptions for orders currently being placed by
the user. This caused in-flight orders to receive their responses on a new subscription
that had not yet returned the dedup'd events, breaking the order flow entirely.

#### Current Workaround

Dispute chat subscriptions remain isolated from `SubscriptionManager`. Each
`DisputeChatNotifier` instance manages its own `StreamSubscription<NostrEvent>`. The
subscription is cancelled on `dispose()` and recreated if the provider is invalidated.

#### Consequence

Relay subscription management is split across two systems. If relay connections are
recycled (e.g. app foreground/background cycle), `SubscriptionManager` resubscribes all
sessions automatically, but dispute chat subscriptions must re-initialize independently via
`DisputeChatNotifier.initialize()`.

---

### Issue 2 — `FormatException: Public key cannot be empty` in `MostroService._onData`

#### Error

```text
FormatException: Failed to parse Peer from JSON: FormatException: Public key cannot be empty
#0   MostroService._onData (mostro_service.dart:172)
```

Line 172 is `final msg = MostroMessage.fromJson(result[0])`.

#### Root Cause

Some Mostro protocol events (typically `adminTookDispute` or similar admin-side messages)
include a `Peer` payload where `public_key` is either an empty string or absent. The
`Peer.fromJson()` constructor throws `FormatException` on empty/missing keys rather than
returning null or a sentinel value.

These events arrive through the normal `SubscriptionManager` → `MostroService._onData`
pipeline. The error is caught by the `catch (e)` block at the bottom of `_onData`, so the
app does not crash, but the message is silently discarded and state is not updated.

This occurs post-restore when the relay replays `adminTookDispute` events that have no
`public_key` in the peer field — possibly because the solver's public key was not yet
assigned at the time of the original event, or the backend serializes an absent solver as
an empty string.

#### Impact

- Event discarded silently — admin-assigned-to-dispute state is not applied.
- If `adminTookDispute` is the only source of `adminSharedKey` in normal flow, dispute chat
  subscriptions will not start. Post-restore this is mitigated by `solverPubkey` set
  directly during the restore session-creation loop (see implementation above).

#### Fix Needed

`Peer.fromJson()` should tolerate an empty or absent `public_key` by returning `null`
rather than throwing. Alternatively, `MostroMessage.fromJson` should catch this specific
case and degrade gracefully (e.g. strip the peer field and continue parsing).

---

### Issue 3 — Dispute State Not Persisted After Restore + App Kill

#### Description

After a successful restore, if the user force-kills the app and relaunches, disputed order
state is not recovered. The orders either show an incorrect status or disappear from
"My Trades". This does **not** happen for users who have never performed a restore.

#### Root Cause (Preliminary)

The normal (non-restore) app startup path relies on `mostroStorage` containing
`MostroMessage` records that were received live from the relay. On restart,
`OrderNotifier.sync()` reads all messages for each orderId from storage and reconstructs
state by replaying them in timestamp order.

After restore, `restore_manager` calls `storage.deleteAll()` to clear relay-replayed events
and then writes fresh `MostroMessage` records derived from `OrdersResponse`. These records
are written with `orderDetail.createdAt` timestamps (original order creation time, which
may be months old). On the next app start, `sync()` replays these messages correctly — but
relay-replayed events that arrive after `isRestoringProvider = false` may be stored with
`DateTime.now()` timestamps (see `MostroService._onData` timestamp behavior) and therefore
sort after the restore messages in `watchLatestMessage` (DESC), causing `state.updateWith`
to apply a stale relay event over the correct restored state.

Additionally, if the `Session` persisted to Sembast after restore does not include
`adminPubkey` / `disputeId` (e.g. due to a serialization gap in `Session.toJson` /
`Session.fromJson`), then on relaunch `adminSharedKey` will be null and dispute chat
subscriptions will not start.

#### Scope

Out of scope for the current restore feature milestone. Tracked here for future resolution.

#### Suspected Files

- `lib/features/order/notifiers/abstract_mostro_notifier.dart` — `sync()` and `subscribe()` replay logic
- `lib/services/mostro_service.dart` — timestamp assignment on relay-replayed events
- `lib/data/models/session.dart` — `toJson()` / `fromJson()` for `adminPubkey` / `disputeId`
