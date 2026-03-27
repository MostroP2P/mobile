# Deep Link Mostro Instance Switch

## Overview

When a deep link contains a `mostro=<pubkey>` parameter identifying a different
Mostro instance than the currently connected one, the app shows a confirmation
dialog before switching.

## Deep Link Format

```text
mostro:<order-id>?relays=<relay1>,<relay2>&mostro=<mostro_pubkey>
```

The `mostro` parameter is optional for backward compatibility. When absent, the
app assumes the order belongs to the currently selected Mostro instance.

## Flow

1. App receives `mostro:` deep link
2. `parseMostroUrl` extracts `orderId`, `relays`, and optional `mostroPubkey`
3. `DeepLinkHandler` compares `mostroPubkey` with `settings.mostroPublicKey`
4. If same (or absent) → navigate directly to order (existing behavior)
5. If different → show confirmation dialog
6. If user confirms → call `updateMostroInstance(newPubkey)` then navigate
7. If user cancels → do nothing

## Files Changed

| File | Change |
|------|--------|
| `lib/shared/utils/nostr_utils.dart` | Extract `mostro` query param in `parseMostroUrl` |
| `lib/services/deep_link_service.dart` | Add `mostroPubkey` field to `OrderInfo` |
| `lib/core/deep_link_handler.dart` | Pubkey comparison + switch dialog |
| `lib/l10n/intl_en.arb` | English strings for dialog |
| `lib/l10n/intl_es.arb` | Spanish strings for dialog |
| `test/shared/utils/deep_link_parsing_test.dart` | Unit tests |

## References

- [Issue #541](https://github.com/MostroP2P/mobile/issues/541)
- [Order Event Spec](https://mostro.network/protocol/order_event.html)
