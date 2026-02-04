# Subscription Loss on Relay Change

## Table of Contents

1. [Overview](#1-overview)
2. [Main Bug: All Subscriptions Destroyed on Relay Change](#2-main-bug-all-subscriptions-destroyed-on-relay-change)
3. [Secondary Bug: Race Condition — "Nostr is not initialized"](#3-secondary-bug-race-condition--nostr-is-not-initialized)
4. [Secondary Bug: Duplicate SubscriptionManager](#4-secondary-bug-duplicate-subscriptionmanager)
5. [Secondary Bug: Null Assertions in NostrEvent Extension](#5-secondary-bug-null-assertions-in-nostrevent-extension)
6. [dart_nostr Internal Behavior (Relevant to Solutions)](#6-dart_nostr-internal-behavior-relevant-to-solutions)
7. [Proposed Solutions](#7-proposed-solutions)
8. [Solution Comparison](#8-solution-comparison)

---

## 1. Overview

Any change to the active relay list — whether triggered by automatic sync with a Mostro instance or by a manual user action in the relay settings screen — destroys all active Nostr subscriptions. The app stops receiving both public order events (kind 38383) and private trade messages (kind 1059). No recovery occurs within the session. The app must be restarted.

A secondary race condition makes all NostrService operations fail with an unhandled exception during the relay transition window. This window exists because the disconnect-reconnect cycle is launched as a fire-and-forget async call while `_isInitialized` is set to `false`.

Both bugs shared the same trigger: the disconnect-reconnect cycle inside `NostrService.updateSettings()`. They operated at different phases of that cycle and required different analysis to understand independently.

**Status:** Both bugs are fixed. Solution A was implemented in `NostrService.updateSettings()` (`nostr_service.dart:75`). The disconnect-reconnect cycle was replaced with an additive `init()` call. Sections 2–3 document the original root causes for reference. Section 7 describes the implementation.

---

## 2. Main Bug: All Subscriptions Destroyed on Relay Change

### 2.1 The Trigger Chain

Every path that modifies the relay list ends at `_saveRelays()` in `RelaysNotifier`. This method persists the new relay list to `settingsProvider`, which is a reactive provider. The persistence and the destruction of subscriptions are linked through a listener that was not designed with this consequence in mind.

```text
User action or sync event
  │
  ▼
RelaysNotifier.addRelay()              relays_notifier.dart:105
RelaysNotifier.removeRelay()           relays_notifier.dart:115
RelaysNotifier.removeRelayWithBlacklist()  relays_notifier.dart:642
RelaysNotifier._handleMostroRelayListUpdate()  relays_notifier.dart:524
  │
  ▼ (all paths converge here)
RelaysNotifier._saveRelays()           relays_notifier.dart:80
  │
  ▼
SettingsNotifier.updateRelays()        settings_notifier.dart:52
  │  state = state.copyWith(relays: newRelays)
  │  await _saveToPrefs()              ← persistence (correct)
  ▼
settingsProvider emits new value       ← reactive notification (the problem starts here)
  │
  ▼
nostrServiceProvider listener          nostr_service_provider.dart:9
  │  nostrService.updateSettings(next) ← called without await
  ▼
NostrService.updateSettings()          nostr_service.dart:75
  │  _isInitialized = false            nostr_service.dart:88
  │  await disconnectFromRelays()      nostr_service.dart:91  ← kills all WebSockets
  │  await init(newSettings)           nostr_service.dart:95  ← opens new WebSockets
  ▼
  All subscriptions are dead.          No one re-creates them.
```

### 2.2 Why Subscriptions Die and Stay Dead

dart_nostr uses a single broadcast `StreamController<NostrEvent>` (`streamsController` in `NostrStreamsControllers`) as the event bus for all relays. Every subscription created via `startEventsSubscription()` is a `.where()` filter on this stream, keyed by `subscriptionId`. The REQ message carrying that `subscriptionId` was sent to specific relays when the subscription was created.

When `disconnectFromRelays()` closes all WebSockets:
- The relays lose all subscription state. They will no longer send events for any previously established `subscriptionId`.
- The `StreamController` itself is NOT closed (it is only closed by `freeAllResources()`). The `.where()` filters remain registered on it. They are alive but will never receive matching events.

When `init()` opens new WebSocket connections:
- dart_nostr does not replay or re-send any previously established REQ messages. It has no record of them after the disconnect cleared the registry.
- The subscription filter streams continue to listen on the broadcast controller, but no relay knows about their `subscriptionId` anymore. Zero events match.

Two components fail to re-create their subscriptions after reconnect:

**OpenOrdersRepository** (`open_orders_repository.dart:125`):
```dart
void updateSettings(Settings settings) {
    if (_settings.mostroPublicKey != settings.mostroPublicKey) {
        _subscribeToOrders();  // only re-subscribes on pubkey change
    } else {
        _settings = settings.copyWith();  // relay-only change: does nothing
    }
}
```

**SubscriptionManager** (`subscription_manager.dart:39`):
```dart
_sessionListener = ref.listen<List<Session>>(
    sessionNotifierProvider,
    (previous, current) {
        _updateAllSubscriptions(current);  // only fires on session changes
    },
    fireImmediately: false,
);
```

**LifecycleManager** (`lifecycle_manager.dart:48`) has the re-subscription logic (`subscribeAll()` + `reloadData()`), but it only runs on background-to-foreground transitions. `_isInBackground` starts as `false` (`lifecycle_manager.dart:17`), so `_switchToForeground()` is never called on the initial app launch.

### 2.3 Reproduction

**Deterministic on first launch:**
1. App starts. `Config.nostrRelays` contains a single relay: `wss://relay.mostro.network` (`config.dart:5`).
2. `SettingsNotifier.init()` finds no saved settings in SharedPreferences. Uses defaults: relays = `['wss://relay.mostro.network']`.
3. `NostrService.init()` connects to that single relay.
4. `OpenOrdersRepository` subscribes to kind 38383/38385 on that relay. Subscription is live. Events arrive.
5. `RelaysNotifier` constructor schedules `syncWithMostroInstance()` via `Future.microtask()` (`relays_notifier.dart:47`).
6. Sync subscribes to kind 10002 from the Mostro pubkey. Receives the relay list event. It contains additional relays.
7. `_handleMostroRelayListUpdate()` processes the event. State changes. Calls `_saveRelays()`.
8. `_saveRelays()` calls `settings.updateRelays()` with the expanded list (e.g., `['wss://relay.mostro.network', 'wss://nostr.com.br', ...]`).
9. Chain fires. `NostrService` disconnects, reconnects. Subscriptions die.
10. Order book is empty. Trades do not update. Creating new orders produces no visible result.

**Also reproducible manually:** Adding or removing any relay through the UI calls `addRelay()`, `removeRelay()`, or `removeRelayWithBlacklist()`. All converge at `_saveRelays()`. Same result.

### 2.4 Why Restart Fixes It Permanently

On restart:
1. `SettingsNotifier.init()` loads from SharedPreferences. The relay list is already the full synced list (saved in step 8 above).
2. `NostrService.init()` connects to all relays from the start. Fresh subscriptions are created on all of them.
3. Relay sync runs again. `_handleMostroRelayListUpdate()` receives the same 10002 event. The relay list it produces matches the current state. The condition at `relays_notifier.dart:622-628` evaluates to false (no change). `_saveRelays()` is not called. `settingsProvider` does not emit. `NostrService.updateSettings()` is never invoked. No disconnect occurs.

### 2.5 Current Behavior (Post-Fix)

The trigger chain is unchanged up to `NostrService.updateSettings()`. The behavior inside that method is what changed:

```text
settingsProvider emits new value
  │
  ▼
nostrServiceProvider listener          nostr_service_provider.dart:9
  │  nostrService.updateSettings(next) ← fire-and-forget (unchanged)
  ▼
NostrService.updateSettings()          nostr_service.dart:75
  │  previousSettings = _settings      ← snapshot for error recovery
  │  await init(newSettings)           ← additive: skips already-connected relays
  │                                    ← _isInitialized stays true throughout
  ▼
  Existing subscriptions continue receiving events. New relays are connected.
```

`init()` calls dart_nostr's `init()`, which sets `relaysList` to the new list and iterates it. For each relay it checks `isRelayRegisteredAndConnectedSuccesfully`. Already-connected relays are skipped. Only new relays get WebSocket connections. The broadcast `StreamController` and all active subscription filters are untouched.

If `init()` fails (e.g., dart_nostr throws while connecting to a new relay), the catch block restores `_settings` to `previousSettings` and sets `_isInitialized = true`. Existing connections are unaffected because no disconnect was performed. The service continues to operate on the previous relay set.

---

## 3. Secondary Bug: Race Condition — "Nostr is not initialized"

> **Fixed by Solution A.** `_isInitialized` is never set to `false` during a relay change. The window described below no longer exists. This section is preserved as a record of the original issue.

### 3.1 Description

`NostrService.updateSettings()` is an `async` method. It is invoked from a `ref.listen` callback that does not `await` the call:

```dart
// nostr_service_provider.dart:9-10
ref.listen<Settings>(settingsProvider, (previous, next) {
    nostrService.updateSettings(next);  // fire-and-forget
});
```

The first statement inside `updateSettings()` when the relay list has changed is:

```dart
// nostr_service.dart:88
_isInitialized = false;
```

This flag is set synchronously, before `disconnectFromRelays()` begins its async work. From this point until `init()` completes and sets `_isInitialized = true` (`nostr_service.dart:66`), every method on `NostrService` that checks this flag will throw:

```text
Exception: Nostr is not initialized. Call init() first.
```

The duration of this window depends on WebSocket close and open latency across all relays. Typical range: 100–600ms. It is not a theoretical window. It is open for a measurable duration on every relay change.

### 3.2 All Affected Methods

Every public method on `NostrService` that is guarded by the `_isInitialized` check will throw if called during the window:

| Method | Line | Called by |
|--------|------|----------|
| `publishEvent()` | 120 | `MostroService.publishOrder()` — all outbound trade actions |
| `fetchEvents()` | 151 | `fetchEventById()`, `fetchOrderInfoByEventId()` — deep link resolution |
| `subscribeToEvents()` | 169 | `SubscriptionManager.subscribe()`, `OpenOrdersRepository._subscribeToOrders()` |
| `createNIP59Event()` | 204 | Gift wrap creation for outbound messages |
| `decryptNIP59Event()` | 217 | Gift wrap decryption for inbound messages |
| `unsubscribe()` | 257 | `Subscription.cancel()` — subscription cleanup |

### 3.3 Concrete Failure Scenario

The most likely scenario involves `publishEvent()`. The relay sync completes while the user is on the order creation screen. The user taps the submit button. The button handler calls `submitOrder()` → `publishOrder()` → `publishEvent()`. The event is never sent.

```text
T=0ms     settingsProvider emits (relay list changed by sync)
T=0ms     nostrServiceProvider listener fires
T=0ms     updateSettings() starts executing
T=0ms     _isInitialized = false                    ← flag set
T=0ms     disconnectFromRelays() starts (async)     ← returns to event loop

          ... Dart event loop continues ...

T=~50ms   User taps "Create Order"
T=~50ms   MostroService.submitOrder()
T=~50ms     → publishOrder()
T=~50ms       → nostrService.publishEvent(event)
T=~50ms         → if (!_isInitialized) throw ...    ← EXCEPTION

          ... disconnectFromRelays() completes ...
T=~200ms  init(newSettings) starts
T=~400ms  init(newSettings) completes
T=~400ms  _isInitialized = true                     ← flag restored
```

The order was never published. The exception propagates up through `submitOrder()`. Depending on error handling in the UI layer, the user may see no feedback at all, or a generic error.

### 3.4 Additional Risk: Concurrent updateSettings Calls

`ref.listen` does not serialize or debounce callbacks. If `settingsProvider` emits twice in rapid succession — for example, `updateRelays()` followed immediately by `updateUserRelays()` in `_saveRelays()` — the listener fires twice. Two `updateSettings()` calls execute concurrently:

```text
Call 1: _isInitialized = false → disconnectFromRelays() (in progress)
Call 2: _isInitialized = false → disconnectFromRelays() (starts while Call 1 is mid-disconnect)
```

`disconnectFromRelays()` in dart_nostr iterates `relaysWebSocketsRegistry` and closes each WebSocket. If two calls run concurrently, they iterate the same registry. One call may close a WebSocket that the other call has already closed, or that `init()` from Call 1 has already re-opened. The result is undefined and depends on dart_nostr's internal state handling.

In practice, `_saveRelays()` calls `updateRelays()` and then `updateUserRelays()` sequentially. `updateRelays()` changes `settings.relays`; `updateUserRelays()` changes `settings.userRelays`. Only `updateRelays()` triggers the relay-list-changed path in `updateSettings()`. The second emit (from `updateUserRelays()`) does not change `relays`, so `ListEquality().equals()` returns true and `updateSettings()` exits early. This specific concurrent-call scenario does not currently fire. However, it is a latent risk if `_saveRelays()` is ever refactored or if another code path emits a relay change while `updateSettings()` is in progress.

### 3.5 Independence from the Main Bug

The race condition is not caused by subscriptions dying. It is a property of the transition mechanism itself. Even if a fix were applied that perfectly re-created all subscriptions after reconnect, this window would still exist. Any operation attempted during the disconnect phase fails regardless of what happens afterward.

| Aspect | Main Bug | Race Condition |
|--------|----------|----------------|
| Phase | After reconnect completes | During disconnect |
| Effect | Subscriptions permanently dead until restart | Individual operations fail transiently |
| Frequency | Deterministic on every relay change | Probabilistic — only if an operation runs during the window |
| User impact | Order book empty, trades frozen | Specific action silently fails (e.g., order not sent) |

---

## 4. Secondary Bug: Duplicate SubscriptionManager

### 4.1 Description

`RelaysNotifier._initMostroRelaySync()` creates a second `SubscriptionManager` instance:

```dart
// relays_notifier.dart:418
_subscriptionManager = SubscriptionManager(ref);
```

This instance is entirely independent of the application's main `subscriptionManagerProvider` (created in `app_init_provider.dart:23`). The `SubscriptionManager` constructor does three things:

```dart
// subscription_manager.dart:32-37
SubscriptionManager(this.ref) {
    _initSessionListener();           // ref.listen(sessionNotifierProvider, ...)
    ref.onDispose(dispose);
    _initializeExistingSessions();    // reads sessionNotifierProvider, creates subscriptions
}
```

The second instance therefore:
- Registers a second listener on `sessionNotifierProvider`.
- Creates duplicate kind 1059 subscriptions whenever sessions exist.
- Sends duplicate REQ messages to relays.

The only stream from this second instance that is actually consumed is `relayList` (for kind 10002 relay sync events). The `orders` and `chat` broadcast streams are created but have zero listeners.

### 4.2 Impact

Functional impact: none. dart_nostr's `eventsRegistry` deduplicates events by ID before adding them to the broadcast stream (`relays.dart:934`). Duplicate subscriptions produce duplicate REQ messages to relays, but events arriving from those subscriptions are deduplicated before reaching application code.

Performance impact: unnecessary WebSocket traffic (duplicate REQ/EVENT messages) and redundant stream processing.

---

## 5. Secondary Bug: Null Assertions in NostrEvent Extension

### 5.1 Description

Three getters in `lib/data/models/nostr_event.dart` use the `!` null-assertion operator on values retrieved from event tags. If the tag is absent from an event, the assertion throws a `TypeError`:

| Getter | Line | Tag key | Throws if tag missing |
|--------|------|---------|----------------------|
| `type` | 43 | `z` | Yes — `TypeError` |
| `status` | 17 | `s` | Yes — `TypeError` |
| `expirationDate` | 40 | `expiration` | Yes — `TypeError` |

### 5.2 Where the Crash Occurs

`type` is the most exposed. It is called inside the `.listen()` onData callback of `OpenOrdersRepository`:

```dart
// open_orders_repository.dart:52-53
_subscription = _nostrService.subscribeToEvents(request).listen((event) {
    if (event.type == 'order') {  // ← throws if 'z' tag missing
```

This runs on every kind 38383 and kind 38385 event before any kind check. If any relay sends an event without a `z` tag, the getter throws. Dart's zone error handler catches it (the subscription stream is not canceled), but the event is silently dropped. No log is emitted at the point of failure.

### 5.3 Impact

Latent. Does not currently cause systematic failures under normal conditions. Any malformed or non-standard event from any relay is silently lost. The failure is invisible unless log-level debugging is enabled and the zone error output is inspected.

---

## 6. dart_nostr Internal Behavior (Relevant to Solutions)

The following facts about dart_nostr 9.1.1 are verified from its source code and directly influence which solutions are viable.

### 6.1 `init()` is Additive

`_startConnectingAndRegisteringRelays()` (`dart_nostr relays.dart:868`) skips any relay already registered and connected:

```dart
if (nostrRegistry.isRelayRegisteredAndConnectedSuccesfully(relay)) {
    continue;
}
```

Calling `init()` with a relay list that includes both existing and new relays will only open connections to the new relays. Existing connections, subscriptions, and the event broadcast stream are untouched.

### 6.2 `disconnectFromRelays()` Clears Everything Except the Event Stream

`disconnectFromRelays()` (`dart_nostr relays.dart:722`):
- Closes every WebSocket in `relaysWebSocketsRegistry`.
- Calls `nostrRegistry.clearWebSocketsRegistry()`.
- Sets `relaysList = []`.
- Does **not** close `streamsController` (the broadcast `StreamController<NostrEvent>`).

After disconnect, the broadcast stream is still open. Subscription filters (`.where()`) registered on it are still active. They simply receive no data because no WebSocket is feeding the stream.

### 6.3 No Per-Relay Disconnect API

There is no public method to disconnect from a single relay. The only disconnect method is `disconnectFromRelays()`, which closes all connections. Additionally, `NostrService.init()` is called with `retryOnClose: true` (`nostr_service.dart:43`), which means dart_nostr will automatically reconnect any WebSocket that closes. Closing a single WebSocket externally (via the `relaysWebSocketsRegistry` getter) would be immediately undone by the retry logic.

### 6.4 Subscription REQs Are Not Replayed

When `init()` opens new WebSocket connections, it does not re-send any REQ messages. Subscriptions are a one-shot operation: the REQ is sent to the relays that are connected at the time `startEventsSubscription()` is called. New relays added afterward do not receive any previously established REQ.

### 6.5 Events Are Deduplicated

`_handleAddingEventToSink()` (`dart_nostr relays.dart:934`) checks `nostrRegistry.isEventRegistered(event)` before adding an event to the broadcast stream. If the same event arrives from multiple relays, only the first instance is delivered to application code.

---

## 7. Proposed Solutions

### Solution A: Additive `init()` Without Disconnect — IMPLEMENTED

**Principle:** Replace the disconnect-reconnect cycle in `NostrService.updateSettings()` with a call to `init()` alone. Since dart_nostr's `init()` is additive (Section 6.1), new relays are connected without touching existing connections. All active subscriptions continue to receive events from their original relays.

**What was removed from `NostrService.updateSettings()`:**

```dart
// REMOVED: set flag to false during update
_isInitialized = false;                          // nostr_service.dart (old line 88)

// REMOVED: disconnect before reconnect
await _nostr.services.relays.disconnectFromRelays();  // nostr_service.dart (old line 91)

// REMOVED: nested restore attempt on failure (no longer needed — nothing was destroyed)
catch (e) {
    await init(settings);  // broken: settings getter returned the already-overwritten value
}
```

**What replaced it (`nostr_service.dart:75-101`):**

```dart
Future<void> updateSettings(Settings newSettings) async {
    if (!ListEquality().equals(settings.relays, newSettings.relays)) {
      if (newSettings.relays.isEmpty) {
        logger.w('Warning: Attempting to update with empty relay list');
        return;
      }

      // Additive init: dart_nostr skips already-connected relays, so existing
      // connections and active subscriptions remain untouched. Only new relays
      // get connected. _isInitialized stays true throughout.
      final previousSettings = _settings;
      try {
        await init(newSettings);
        logger.i('Successfully added new relays: ${newSettings.relays}');
      } catch (e) {
        // init() failed on new relays but existing connections are still live.
        // Restore previous settings and keep the service operational.
        logger.w('Failed to connect to new relays, current relays remain active: $e');
        _settings = previousSettings;
        _isInitialized = true;
      }
    }
}
```

**Why the catch block is required:**

`init()` (`nostr_service.dart:29-73`) sets `_settings = settings` at line 36, before the `try` block. If dart_nostr throws during connection, `init()`'s own catch sets `_isInitialized = false` and rethrows. At that point both `_settings` and `_isInitialized` are in a bad state despite existing connections being alive. The catch in `updateSettings()` snapshots `previousSettings` before the call and restores both fields on failure. This is the only technically non-obvious aspect of the implementation.

**Behavioral consequences:**

- **Relay sync (adding relays):** New relays connect. Existing subscriptions continue on their current relays without interruption. The next time subscriptions are re-created (foreground transition via `LifecycleManager`, or app restart), the new relays receive fresh REQs and contribute events.
- **Manual relay addition:** Same as above. The new relay is immediately connected but does not receive subscription REQs until the next `reloadData()` or restart.
- **Relay removal:** The removed relay's WebSocket remains open. There is no per-relay disconnect API (Section 6.3). The relay stays registered until app restart. `LifecycleManager._switchToForeground()` does not call `disconnectFromRelays()` — it only re-creates subscriptions. During this time, events from the removed relay are deduplicated (Section 6.5) and cause no functional impact.

**Pros:**
- Fixes the main bug: subscriptions are never interrupted.
- Eliminates the race condition: `_isInitialized` is never set to `false` during a relay change.
- Minimal code change. The modification is contained within `NostrService.updateSettings()`.
- Relies on dart_nostr's designed behavior, not a workaround.
- `_waitForNostrService()` in `RelaysNotifier` (used before subscribing to Mostro's kind 10002) always returns immediately now, because `isInitialized` is never transiently `false`.

**Cons:**
- Removed relays remain connected until app restart. Functionally harmless but leaves an unnecessary WebSocket open. (`LifecycleManager` does not disconnect on foreground transition — it only calls `subscribeAll()` and `reloadData()`.)
- New relays do not receive subscription REQs for existing subscriptions. Events from new relays only begin arriving after the next `reloadData()` call (foreground transition) or restart. The default relay (`relay.mostro.network`) continues to deliver all events in the interim, because Mostro publishes to its own relays.

---

### Solution B: Decouple Persistence from Reconnection

**Principle:** The listener in `nostrServiceProvider` no longer triggers a reconnection when the relay list changes. `_saveRelays()` continues to persist to SharedPreferences as before. Reconnection and re-subscription happen only at explicitly controlled points — specifically, in `LifecycleManager._switchToForeground()`, which already performs `subscribeAll()` and `reloadData()`.

**What changes:**

- `nostrServiceProvider` listener: the call to `nostrService.updateSettings()` is removed or conditioned to skip relay-only changes.
- `LifecycleManager._switchToForeground()`: an `await nostrService.updateSettings(currentSettings)` call is added before `subscribeAll()` and `reloadData()`. This ensures the relay connections are updated before subscriptions are re-created on them.

**Behavioral consequences:**

- **Any relay change (sync or manual):** Persisted immediately. Active connections and subscriptions are unchanged. The app continues to operate on the relay set that was active at the start of the session.
- **Foreground transition:** `updateSettings()` runs, reconnects if the relay list changed since last transition, then `subscribeAll()` + `reloadData()` re-create all subscriptions on the updated relay set.
- **First launch:** The app operates on the single default relay until the first background-to-foreground transition. Relay sync runs, saves the expanded list, but does not reconnect. Events from the default relay arrive normally.

**Pros:**
- Zero race conditions during normal app operation. Reconnection only happens at a point where re-subscription immediately follows.
- Clean architectural separation between persistence (always immediate) and active network state (updated at lifecycle boundaries).
- Re-subscription logic already exists in `_switchToForeground()`. The change is additive.

**Cons:**
- New relays (both synced and manually added) are not active until the next background-to-foreground transition.
- If a user adds a relay and expects it to be immediately usable, it is not. The relay becomes active on the next foreground transition, which in practice is the next time the user switches away from and back to the app.

---

### Solution C: Await and Re-subscribe After Reconnect

**Principle:** Keep the disconnect-reconnect cycle in `NostrService.updateSettings()`. Change the listener in `nostrServiceProvider` to `await` the result, then explicitly re-create all subscriptions that were destroyed.

**What changes in `nostrServiceProvider`:**

```dart
ref.listen<Settings>(settingsProvider, (previous, next) async {
    await nostrService.updateSettings(next);
    ref.read(subscriptionManagerProvider).subscribeAll();
    ref.read(orderRepositoryProvider).reloadData();
    ref.read(mostroServiceProvider).init();
});
```

**Behavioral consequences:**

- **Any relay change:** Disconnect, reconnect, then immediately re-create all subscriptions. New relays receive fresh REQs. Events from all relays (old and new) begin arriving within the reconnect window.

**Pros:**
- Relay changes take full effect immediately. Both old and new relays are active and subscribed.
- No application-visible gap in event delivery beyond the reconnect duration.

**Cons:**
- **The race condition (Section 3) persists.** `_isInitialized` is `false` from `nostr_service.dart:88` until `init()` completes. Any concurrent operation during that window throws. The `await` in the listener does not prevent other code from running during the same window — Dart's event loop continues processing other callbacks and timers.
- **The listener callback is async but `ref.listen` does not await it.** Riverpod calls the callback and moves on. The code after `await` runs when `updateSettings()` completes, but Riverpod has no knowledge of this. If `settingsProvider` emits again before the first callback completes, a second execution begins concurrently (Section 3.4).
- **A guard mechanism is required.** A flag or mutex must be added to prevent concurrent `updateSettings()` executions. Without it, two disconnect cycles can interleave and corrupt relay state.
- Medium code-change scope. Requires coordinating across `nostrServiceProvider`, `subscriptionManagerProvider`, `orderRepositoryProvider`, and `mostroServiceProvider`.

---

## 8. Solution Comparison

| Criterion | A — Additive init ✅ implemented | B — Decouple | C — Await + re-subscribe |
|---|---|---|---|
| Main bug fixed | Yes | Yes | Yes |
| Race condition fixed | Yes | Yes | No — requires additional guard |
| New relays immediately active | Partial (connected, not subscribed) | No (next foreground transition) | Yes |
| Relay removal takes effect immediately | No (next foreground transition) | No (next foreground transition) | Yes |
| Code change scope | Low | Low | Medium |
| Risk of new bugs introduced | Very low | Very low | Medium (concurrent execution, guard logic) |
| Leverages dart_nostr design | Yes (additive init) | Yes (lifecycle boundaries) | Partially (keeps the disconnect pattern) |
| Eliminates both bugs with single change | Yes | Yes | No |

Solution A was selected and implemented. It is the lowest-risk option that fixes both the main bug and the race condition with a single change to `NostrService.updateSettings()` (`nostr_service.dart:75`). Its trade-offs (removed relays linger until foreground transition; new relays do not receive subscription REQs until the next `reloadData()`) are functionally inconsequential under normal usage: the default relay delivers all Mostro events, and `LifecycleManager` already handles the full reconnect-and-resubscribe cycle on every foreground transition.

---

**Last Updated:** February 4, 2026
