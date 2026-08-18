# Dispute Chat Kind-14 Envelope

> Wire format, key derivation, and client rules for the user↔admin dispute chat.
> Replaces the legacy 1-layer gift wrap (kind 1059) previously used for dispute chat.
> Protocol spec: https://mostro.network/protocol/chat.html (envelope, key derivation,
> test vector) and https://mostro.network/protocol/dispute_chat.html (per-party admin
> keys and dispute flow)

## Overview

Dispute chat messages between a user and the assigned admin (solver) are exchanged as
**kind 14 events** signed by a conversation-specific key, instead of gift wraps addressed
to the raw ECDH shared pubkey. The Mostro daemon is not a party to this chat: both sides
derive the same keys from their ECDH secret and talk directly through relays.

The reference implementations are `mostro_core::chat` (Rust) and mostrix
(`src/util/chat_utils.rs`). Mostrix sends **only** the kind-14 envelope, so this format is
required for mobile users to receive admin messages.

## Key Derivation

The ECDH shared secret is unchanged from the legacy system — it is still
`session.adminSharedKey`, computed as `ECDH(tradeKey.private, adminPubkey)` when
`adminTookDispute` arrives (`session.setAdminPeer()`). What changed is that the secret is
no longer used on the wire directly. It is expanded with HKDF-SHA256 (zero-filled salt)
into two domain-separated keys:

```text
ECDH(tradeKey, adminPubkey)  →  32-byte shared secret (IKM)
HKDF-SHA256(salt=zeros, ikm=secret):
    expand(info="mostro:chat:conv:v1") → K_conv   (NIP-44 encryption + p tag)
    expand(info="mostro:chat:sign:v1") → K_sign   (signs the outer kind 14)
```

If an expanded output is not a valid secp256k1 secret key (negligible probability), the
derivation retries with a counter byte appended to the info, per the spec.

**Implementation:** `ChatKeys` in `lib/shared/utils/chat_keys.dart`
(`ChatKeys.fromSharedKey(session.adminSharedKey!)`). The official test vector from the
spec is verified in `test/shared/utils/chat_keys_test.dart`.

## Wire Format

```text
Plain-text message
    → kind 1 TextNote signed by the sender's trade key (no tags)
    → NIP-44 v2 self-encryption under K_conv (same key on both sides)
    → kind 14 outer event:
        pubkey     = pub(K_sign)          ← signed by K_sign
        content    = NIP-44 ciphertext
        tags       = exactly ONE p tag = pub(K_conv)
        created_at = same real timestamp as the inner event
```

Unlike the legacy gift wrap, the outer timestamp is **real** (not randomized): recipients
reject a mismatch between inner and outer timestamps as a replay defense.

**Implementation:** `chatWrap()` / `chatUnwrap()` extensions in
`lib/data/models/nostr_event.dart`.

## Subscription

```dart
NostrFilter(
  kinds: [14],
  authors: [chatKeys.sign.public],
  since: cursorSince ?? chatDefaultLookback, // persisted per-conversation cursor
  limit: NostrEventExtensions.chatDefaultLimit, // 100
)
```

The spec requires filtering by `authors`, **never by `#p`**: a `#p` filter would let any
third party flood the subscription with junk events tagged to the conversation pubkey.

The backlog is bounded by a **durable per-conversation `since` cursor**
(`ChatCursorStore`, persisted in SharedPreferences), as the spec mandates:

- The cursor advances **only after `chatUnwrap` accepts an event**, clamped to
  `min(accepted_timestamp, local_now)` so a future-dated event within the skew tolerance
  cannot suppress later messages.
- Subscriptions use `cursor − 10 min` (overlap window) so an event late-delivered by a
  slow relay is not filtered out forever; outer-id dedup absorbs the re-delivered tail.
- Conversations with no accepted events yet fall back to the spec-default 7-day lookback
  (`chatDefaultLookback`).
- The grouped `SubscriptionManager` filter covers several conversations with one REQ, so
  it uses the **earliest** cursor across sessions — wider than necessary for some
  conversations, which dedup absorbs, but never narrower. Persisted cursors are
  **warmed up from storage before the filter is built**, so a cold start (and the
  background filters persisted from it) uses the durable cursor, not the default
  lookback.

Kind 14 is also used by transport-v2 Mostro protocol messages (user↔mostro). The two
never collide: protocol events are authored by the Mostro pubkey and addressed to the
trade key, chat events are authored by `pub(K_sign)`. Routing always checks the author.

## Validation on Receive

`chatUnwrap()` runs the mandatory spec checks cheapest-first:

1. Outer author == `pub(K_sign)`
2. Outer kind == 14
3. Exactly one `p` tag, equal to `pub(K_conv)`
4. Outer `created_at` not more than 60 s in the future vs. the local clock
5. Encrypted content ≤ 64 KiB, checked before any crypto
6. Outer event id recomputed and signature verified
7. NIP-44 decrypt with K_conv; parse the inner event
8. Inner event id recomputed and signature verified
9. Inner pubkey ∈ allowed signers — `[tradeKey.public, adminPubkey]`
10. Inner kind == 1
11. |inner.created_at − outer.created_at| ≤ 60 s

The event id is recomputed (not just signature-checked) because a BIP-340 signature only
covers the id — without recomputation a tampered body with a stale id/sig pair would pass.

Duplicate detection stays caller-owned: the notifier dedups relay re-deliveries by outer
event id (`eventStore.hasItem`) and UI state by inner event id.

## Implementation Map

| Concern | File |
|---------|------|
| Key derivation (`ChatKeys`) | `lib/shared/utils/chat_keys.dart` |
| Envelope (`chatWrap`/`chatUnwrap`) | `lib/data/models/nostr_event.dart` |
| Dispute chat notifier (subscribe/send/receive/history) | `lib/features/disputes/notifiers/dispute_chat_notifier.dart` |
| Centralized `disputeChat` filter (also reused by background) | `lib/features/subscriptions/subscription_manager.dart` |
| Durable `since` cursor (`ChatCursorStore`) | `lib/services/chat_cursor_store.dart` |
| Background push routing (`author == pub(K_sign)`) | `lib/features/notifications/services/background_notification_service.dart` |
| Derivation + envelope tests (incl. official test vector) | `test/shared/utils/chat_keys_test.dart`, `test/data/models/nostr_event_chat_test.dart` |

## Migration Notes

- **Full wire replacement.** Sending and network subscriptions use only kind 14. There is
  no network dual-read of legacy kind-1059 chat events.
- **Local history keeps a legacy branch.** Dispute messages stored on disk before the
  migration are kind-1059 gift wraps; `_loadHistoricalMessages()` unwraps stored events by
  kind (14 → `chatUnwrap`, 1059 → `p2pUnwrap`), so existing history stays visible.
- **Known accepted gap:** legacy 1059 chat events still sitting on relays but never
  received before the app update are not fetched after it.
- **P2P peer chat (buyer↔seller) uses this same envelope** (`ChatKeys` +
  `chatWrap`/`chatUnwrap`), with the conversation keys derived from the peer shared key
  instead of the admin one. See `P2P_CHAT_SYSTEM.md`. `p2pUnwrap` remains only for
  pre-migration history stored on disk (both chats).
- **Multimedia is unaffected.** Attachment encryption (ChaCha20-Poly1305) keys off the raw
  ECDH secret bytes (`NostrUtils.sharedKeyToBytes(adminSharedKey)`), not K_conv/K_sign, so
  Blossom attachments remain compatible in both directions.

## Privacy Trade-off (by design)

The legacy gift wrap randomized the outer timestamp and used a fresh ephemeral author per
message. The kind-14 envelope has a real timestamp and a stable per-dispute author
(`pub(K_sign)`) — visible metadata the spec accepts in exchange for flood-resistant
author-based filtering. This is a protocol decision, not something the client should work
around.
