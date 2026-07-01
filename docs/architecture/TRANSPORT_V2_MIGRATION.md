# Transport v2 Migration (Protocol v1 → v2)

How the Mostro Mobile app will speak **both** wire transports — protocol **v1**
(NIP-59 gift wrap, kind `1059`) and protocol **v2** (NIP-44 direct, signed
kind `14`) — selecting per node, so it interoperates with old and new daemons
during the migration window.

> **Scope.** The transport is a **protocol-level** change. Only the *envelope*
> changes; the logical Mostro messages, the action set, the payload shapes and
> the key derivation are identical across v1 and v2. This document describes
> only what the **client** must do. For protocol-level details consult the
> official source:
>
> - **Migration spec**: https://mostro.network/protocol/transport_migration.html
> - **Instance status / `protocol_version`**: https://mostro.network/protocol/other_events.html
> - **Protocol docs**: https://mostro.network/protocol/
> - **Daemon repo**: https://github.com/MostroP2P/mostro
> - **Reference client (CLI)**: `MostroP2P/mostro-cli` PRs #176, #177, #178 and
>   its `docs/TRANSPORT_V2_SPEC.md`.
>
> **Status.** **Migration complete.** All phases (§5) are implemented and
> merged: dual receive (A), dual send (B), per-node `protocol_version`
> auto-detection and transport wiring (folded into A/B), the `version`-field
> cleanup (C), and the test suite (D). The app speaks both transports and
> selects per node; the v1 gift-wrap path is unchanged and the v2 NIP-44 path
> engages automatically against a node advertising `protocol_version=2`.

---

## 1. Overview

Mostro is moving its wire transport from **gift wrap** (kind `1059`) to
**NIP-44 direct messages** (kind `14`).

- **v1 — gift wrap (current, what the app does today).** The Mostro message is
  wrapped NIP-59 style (rumor → seal → wrap) and published as a kind-`1059`
  event whose outer author is a throwaway ephemeral key. Strong metadata
  privacy, but relays cannot tell legitimate traffic from garbage without fully
  decrypting NIP-44, which makes spam rate-limiting hard.
- **v2 — NIP-44 direct (new).** The Mostro message is NIP-44 encrypted directly
  to the node's pubkey and published as a kind-`14` event **signed by the trade
  key** — the trade key is the visible event author and its signature is
  load-bearing. Because trade keys are already single-trade and rotated,
  exposing one leaks little. This lets relays rate-limit by sender and lets the
  daemon pre-validate cheaply before decrypting (the Phase 2 anti-spam gate).

### Why both, and for how long

Each node advertises which transport it speaks via the `protocol_version` tag on
its kind-`38385` instance-status event (§2). The daemon rollout is staged:

| Daemon release | v2 available | Default transport | v1 removed |
|---|---|---|---|
| v0.18.0 | yes | v1 (gift wrap) | no |
| v0.19.0 | yes | **v2 (NIP-44)** | yes |

The official recommendation is to **keep both wrap paths and select per node**
from `protocol_version`. A v1-only client cannot talk to a v2-only node at all
(it never sees kind-14 traffic, and its gift wraps are ignored), so dual support
is mandatory to keep working across the window.

### The principle

The app keeps its current v1 path untouched and **adds** a v2 path beside it. A
single per-node resolution of the transport (derived from the node's
`protocol_version`) drives both send and receive. There is **no UI** and no
manual override: detection is automatic (decision below).

### Decisions (fixed)

1. **Transport selection: auto-detection only.** Read `protocol_version` from
   the node's kind-`38385` event. `"2"` → v2; `"1"` or absent → v1. No settings
   toggle.
2. **`version` field tied to transport.** Send `version: 1` on the gift-wrap
   path (preserves today's exact wire for already-deployed daemons) and
   `version: 2` on the NIP-44 path. Conservative and maximally compatible.

---

## 2. Discovering the node's transport

A node advertises its transport in its kind-`38385` info event via a
`protocol_version` tag:

```text
["protocol_version", "1"]   → NIP-59 gift wrap (kind 1059), DEPRECATED
["protocol_version", "2"]   → NIP-44 direct (kind 14)
(tag absent)                → legacy daemon → treat as v1
```

The client already parses this event into `MostroInstance`
(`lib/features/mostro/mostro_instance.dart`). Today the extension reads tags
like `pow`, `bond_enabled`, etc. (`lib/features/mostro/mostro_instance.dart:119-251`)
and the model holds them (`lib/features/mostro/mostro_instance.dart:18-117`).
The migration adds a `protocolVersion` field parsed from `protocol_version`,
**defaulting to `1` when the tag is missing or unparseable** — exactly the
three-state defensive pattern already used for `bond_enabled`
(`lib/features/mostro/mostro_instance.dart:180-190`).

The connected node's `MostroInstance` is already fetched during order
subscription (`lib/data/repositories/open_orders_repository.dart:41-59`) and is
already read on the send path for PoW
(`lib/services/mostro_service.dart:341-343`), so the transport decision has a
natural home with no new fetch.

---

## 3. Wire format: v1 vs v2

| | v1 (`gift-wrap`) | v2 (`nip44`) |
|---|---|---|
| event kind | `1059` | `14` |
| outer author | throwaway ephemeral key | **the trade key** (signature load-bearing) |
| layers | rumor (k1) → seal (k13) → wrap (k1059) | single k14 event, NIP-44 encrypted content |
| inner payload | 2-tuple `[message, sig?]` | 3-tuple `[message, tradeSig?, identityProof?]` |
| identity proof | carried inside the seal | carried **inside** the NIP-44 ciphertext |
| `message.version` | `1` | `2` |
| expiration | none | optional NIP-40 tag — **this client omits it** (§3.3, §5) |

### 3.1 The Mostro message (identical logical content)

Both transports carry the same logical message produced by
`MostroMessage.toJson()` (`lib/data/models/mostro_message.dart:28-41`), wrapped
under an `order` / `restore` key (`lib/data/models/mostro_message.dart:115-126`).
The only field that differs is `version` (decision #2). Example `new-order`:

```json
{
  "order": {
    "version": 1,
    "request_id": 12345,
    "trade_index": null,
    "action": "new-order",
    "payload": { "order": { "kind": "sell", "fiat_code": "VES", "...": "..." } }
  }
}
```

### 3.2 v1 inner payload — 2-tuple (unchanged)

`MostroMessage.serialize()` produces the current 2-tuple
(`lib/data/models/mostro_message.dart:115-126`):

```json
["{\"order\": { ... , \"version\": 1 }}", "<trade-key signature hex>"]
```

This string becomes the rumor content, sealed and gift-wrapped by
`MostroMessage.wrap()` (`lib/data/models/mostro_message.dart:128-161`) using
`NostrUtils.createRumor` / `createSeal` / `createWrap`
(`lib/shared/utils/nostr_utils.dart:236-312`).

### 3.3 v2 inner payload — 3-tuple

```json
[
  "{\"order\": { ... , \"version\": 2 }}",
  "<trade-key signature hex or null>",
  ["<identity pubkey hex>", "<identity signature hex>"]
]
```

- **Element 0** — the same serialized Mostro message JSON (with `version: 2`).
- **Element 1** — the trade-key signature over that message (the same signature
  v1 puts in tuple position 1; see `MostroMessage.sign`,
  `lib/data/models/mostro_message.dart:100-113`).
- **Element 2** — the **identity proof**, or `null` in full-privacy mode. It is
  `["<identity pubkey>", "<identity sig>"]`, where the signature is over a
  domain-tagged payload:

  ```text
  mostro-transport-v2-identity:<trade pubkey hex>:<message JSON>
  ```

  signed with the **identity (master) key**. This is the v2 equivalent of v1's
  seal-carried identity: equally private (it lives inside the NIP-44
  ciphertext, never at the event level) and it binds the identity to the
  authoring trade key.

This entire 3-tuple JSON string is NIP-44 encrypted with `tradeKey.private` →
`mostroPubkey` and placed in the `content` of a kind-`14` event that is **signed
by the trade key** and carries a `["p", "<mostroPubkey>"]` tag. The NIP-40
`["expiration", "<unix>"]` tag is **optional and this client omits it** — the
daemon manages its own expiration and accepts events with or without it (§5
Phase B).

### 3.4 Kind 14 is overloaded — disambiguation

The app already uses kind `14`-adjacent gift-wrapped kind-1 events for NIP-17
peer-to-peer chat (`p2pWrap` / `p2pUnwrap` in `lib/data/models/nostr_event.dart:265-350`).
Protocol-v2 Mostro messages are *also* kind `14`. They are disambiguated on
receive by **author** and **`p` tag**: a v2 Mostro reply is authored by
`mostroPubkey` and addressed (`p`) to the trade key, so the receive filter pins
`authors = [mostroPubkey]`. **Peer chat is out of scope and stays as-is.**

### 3.5 Send/receive flow comparison

```text
v1 (gift wrap)                          v2 (NIP-44 direct)
--------------                          ------------------
build message JSON (version:1)          build message JSON (version:2)
serialize -> [msg, tradeSig]            serialize -> [msg, tradeSig, identityProof?]
rumor (k1, NIP-44)                      NIP-44 encrypt tuple (tradeKey -> mostro)
  -> seal (k13, NIP-44)                 wrap in k14 event:
    -> wrap (k1059, ephemeral author)     - author = trade key (SIGNED)
      - p tag = mostro pubkey             - p tag = mostro pubkey
      - optional PoW (NIP-13)             - (no expiration tag; §3.3)
publish                                   - optional PoW (NIP-13, first-contact)
                                        publish
```

---

## 4. Solution design

### 4.1 Per-node transport resolution

A single source of truth: the connected node's transport, modelled as a small
enum rather than a raw integer threaded through the code, so send and receive
cannot drift out of sync and the `version` field can never be set independently
of the chosen transport:

```dart
enum Transport { giftWrap, nip44 } // v1 / v2
```

One small resolver maps the node (via `MostroInstance.protocolVersion`, §2) to a
`Transport`, and that single value is consumed by **both** the send path and the
receive subscription filters. No UI, no persisted setting, no per-message
override.

Degrade safely: when the `protocol_version` tag is absent or the node is
unreachable, resolve to **`Transport.giftWrap` (v1)** rather than mis-pairing —
this is the version-skew guard. The downgrade must be **logged explicitly** (at
`warn`) so a misconfigured or unreachable node cannot silently leave the app in
a degraded transport without anyone noticing.

### 4.2 `version` field is derived from the transport

The global `Config.mostroVersion` constant has been **removed**. The message
`version` is now a function of the wire transport: `MostroMessage.toJson({int?
version})` defaults to `1` (gift wrap — used by storage, logging and the v1 send
path), and `wrapNip44` passes `version: 2` explicitly. The same serialized
message JSON is reused for the tuple, the trade signature and the identity-proof
payload, so element 0, element 1 and element 2 can never drift apart.

### 4.3 Touch points (current v1 code → where v2 plugs in)

| Concern | Current location |
|---|---|
| Message serialize (2-tuple) | `lib/data/models/mostro_message.dart:115-126` |
| Wrap (rumor→seal→wrap) | `lib/data/models/mostro_message.dart:128-161` |
| `version` in `toJson` | `lib/data/models/mostro_message.dart:28-41` |
| NIP-59 primitives | `lib/shared/utils/nostr_utils.dart:236-312` |
| Publish + PoW + recipient | `lib/services/mostro_service.dart:338-360` |
| Receive subscription filters (kind 1059) | `lib/features/subscriptions/subscription_manager.dart:121-160` |
| Receive decrypt (unWrap → `result[0]`) | `lib/services/mostro_service.dart:129-155` |
| Background receive decrypt (unWrap → `result[0]`) | `lib/features/notifications/services/background_notification_service.dart:199-322` |
| NIP-59 unwrap | `lib/shared/utils/nostr_utils.dart:383-443` |
| Node info / `protocol_version` parse | `lib/features/mostro/mostro_instance.dart:119-251` |
| `version` derived from transport (no global constant) | `lib/data/models/mostro_message.dart` (`toJson`) |

---

## 5. Implementation phases

The phases below define the code work for **subsequent branches**; this
document does not execute them. Each phase keeps the v1 path behaviourally
unchanged.

### Phase A — Dual receive (with receive-side auto-detection)

- Parse `protocol_version` into `MostroInstance.protocolVersion` (default v1 when
  absent or unparseable) — `lib/features/mostro/mostro_instance.dart`. Resolve a
  per-node `Transport` from it (`lib/features/mostro/transport.dart`), degrading
  to v1 on an unsupported value and logging it (version-skew guard, §4.1).
  > Receive-side detection lives here (not Phase C) so the dual-receive path is
  > actually reachable and reviewable; Phase C only threads the resolved
  > transport into the **send** path.
- Make the subscription filters transport-aware
  (`lib/features/subscriptions/subscription_manager.dart`): for a v2 node,
  subscribe to kind `14` pinned to `authors = [mostroPubkey]` and
  `p = [tradeKeys]`, instead of kind `1059`. The node info (kind 38385) arrives
  asynchronously, so the manager listens to `OpenOrdersRepository`'s info-event
  stream and re-subscribes when the resolved transport changes.
- Add a v2 unwrap (sibling to `NostrUtils.decryptNIP59Event`,
  `lib/shared/utils/nostr_utils.dart:383-443`): verify the kind-14 event
  signature (author = node), NIP-44 decrypt `content` with `tradeKey.private` +
  `event.pubkey`, parse the 3-tuple, take `message = tuple[0]`.
- Branch `MostroService` receive (`lib/services/mostro_service.dart:129-155`):
  v1 yields an inner rumor whose content is the 2-tuple; v2's decrypted content
  **is** the tuple directly. Both converge on `MostroMessage.fromJson(tuple[0])`.
- Apply the **same receive branch to the background isolate**
  (`lib/features/notifications/services/background_notification_service.dart`):
  accept kind `14` in `_decryptAndProcessEvent` and branch `_handleTradeKeyEvent`
  on `event.kind`. The background isolate has no Riverpod settings provider, so
  the node pubkey (the v2 author to verify) is read from persisted settings
  (`SharedPreferencesKeys.appSettings`). Without this, v2 replies received while
  the app is backgrounded would be silently dropped once a node advertises
  `protocol_version=2`.

### Phase B — Dual send

- Add a v2 `wrap` (sibling to `MostroMessage.wrap`,
  `lib/data/models/mostro_message.dart:128-161`) that: builds the message with
  `version: 2`; computes the trade signature; computes the identity proof
  (domain-tagged string signed with the master key, `null` in full-privacy);
  NIP-44 encrypts the 3-tuple toward the node; emits a kind-`14` event **signed
  by the trade key** with a `p` tag (the NIP-40 `expiration` tag is omitted; see
  the note below).
- Route **every** outbound Mostro send through the resolved transport via a
  single `MostroMessage.wrapForTransport(protocolVersion: …)` entry point — not
  just `MostroService.publishOrder`, but also the `RestoreManager` requests
  (restore, order-details, last-trade-index) and
  `DisputeRepository.createDispute`, so a v2 node never receives a stray v1 gift
  wrap. **Preserve PoW** (`NostrUtils.mineProofOfWork`) for the first-contact
  lane — the daemon may still require PoW on the kind-14 event id.
- **Identity proof signature** mirrors `mostro-core`'s `transport.rs`: the
  trade-key signature (tuple element 1) is the existing `MostroMessage.sign`
  (SHA-256 hex digest then Schnorr), and the identity proof (element 2) is the
  master key signing `mostro-transport-v2-identity:<tradePubkey>:<messageJSON>`
  with the same scheme. Both are `null` in full-privacy mode.
- The NIP-40 `expiration` tag is **omitted**. It is optional: `mostro-core`
  supports it and the daemon accepts events with or without it (its receive path
  does not validate expiration; it manages its own window). Reference clients
  differ — the Rust app and `mostro-cli` also omit it, while `Mostrix` adds a
  default 30-day window. This client omits it, avoiding any risk of a message
  expiring before processing; adding a generous window later is a safe, optional
  hygiene improvement.

### Phase C — Wiring & finalization ✅

> Send-side transport wiring landed with Phase B: every outbound Mostro send
> already routes through `MostroMessage.wrapForTransport(protocolVersion: …)`,
> and receive-side detection landed with Phase A. This phase finalized the
> remaining loose ends.

- Removed the global `Config.mostroVersion`; the message `version` is derived
  from the transport (§4.2).
- Extracted the transport → orders-filter mapping into the testable top-level
  `buildOrdersFilter` (`subscription_manager.dart`).
- The version-skew guard (`resolveTransport`) degrades to v1 on an unsupported
  protocol version and logs it (§4.1).

### Phase D — Tests ✅

- v2 `wrap` → `unwrap` round-trip, reputation and full-privacy
  (`test/data/mostro_message_nip44_test.dart`): produces a kind-14 event
  authored by the trade key and decodes back to the same message; cryptographically
  verifies the trade signature and the identity proof, including the exact domain
  string `mostro-transport-v2-identity:<tradePubkey>:<messageJSON>` (`null` in
  full-privacy).
- `protocol_version` tag parse → transport mapping, including absent → v1
  (`test/features/mostro/transport_test.dart`,
  `test/features/mostro/mostro_instance_test.dart`).
- Orders subscription filter is transport-aware
  (`test/features/subscriptions/orders_filter_test.dart`).
- Restore decode handles both transports and yields identical results
  (`test/features/restore/restore_decode_test.dart`).
- Regression: the v1 gift-wrap path is byte-for-byte unchanged (existing
  serialization tests stay green).

---

## 6. Backward compatibility and edge cases

- **Legacy node (no `protocol_version` tag)** → resolve to v1; behaviour
  identical to today. The resolver logs this downgrade at `warn` (§4.1) so a
  misconfigured node is not silently left on the degraded transport.
- **`version` field** → v1 keeps `version: 1` on the wire (decision #2), so
  already-deployed pre-0.13 daemons are unaffected. (A 0.13+ daemon dispatches
  on event **kind**, not on `version`, and `verify()` checks action↔payload
  shape, not version — so the field value is never load-bearing for routing.)
- **Transport mismatch** → if the app sent v1 to a v2-only node (or vice-versa),
  the node never sees the traffic and the request times out. Auto-detection
  prevents this; the existing 10-second session-timeout cleanup is the backstop.
- **Full-privacy mode** → identity proof element is `null`; the trade key is
  still the event author. No identity linkage, exactly as v1 full-privacy.
- **PoW first-contact lane** → still applies in v2; PoW is mined on the kind-14
  event id. Keep `mineProofOfWork` and the `maxPowDifficulty` guard.
- **NIP-17 peer chat (also kind 14)** → not touched; disambiguated from Mostro
  v2 by `author = mostroPubkey` + `p` tag.
- **Disputes now carry identity in reputation mode** →
  `DisputeRepository.createDispute` passes the master key + key index through
  `wrapForTransport`, so a reputation-mode dispute binds identity like every other
  Mostro send. Previously disputes were always sent full-privacy-shaped
  (`event.identity = trade key`), ignoring the user's privacy mode. This is a
  deliberate change to the v1 dispute wire — the one exception to "v1
  byte-for-byte unchanged" — and was confirmed accepted by the daemon on **both
  v1 and v2**. The daemon does not require it (`check_trade_index` skips disputes;
  `dispute_action` identifies the disputer by event sender), so full-privacy
  disputes stay identity-less as before.

---

## 7. Out of scope

- Mostro message logic, the action set, and payload shapes (unchanged across
  transports).
- Hierarchical key derivation (trade keys / master key) — unchanged.
- NIP-17 peer-to-peer chat and dispute chat transports.
- Any user-facing UI (selection is automatic).

---

**Last Updated**: 2026-07-01
**Related docs**: `NOSTR.md` (Nostr integration), `MULTI_MOSTRO_SUPPORT.md`
(kind-38385 info-event parsing), `ANTI_ABUSE_BOND.md` (info-event tag parsing
and PoW), `SESSION_AND_KEY_MANAGEMENT.md` (trade vs master keys).
