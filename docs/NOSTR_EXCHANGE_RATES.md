# Nostr Exchange Rates

## Overview

Mostro mobile fetches Bitcoin/fiat exchange rates from Nostr relays (NIP-33 kind `30078`), with automatic fallback to the Yadio HTTP API and a local SharedPreferences cache.

This solves the censorship problem: the Yadio API is blocked in Venezuela and other regions, but Nostr relays are accessible.

## How It Works

```text
Request rate for USD
        │
        ▼
  ┌─ In-memory cache hit? ──→ return rate
  │         │ miss
  │         ▼
  │  ┌─ Nostr (10s timeout) ──→ cache + return
  │  │         │ fail
  │  │         ▼
  │  │  ┌─ Yadio HTTP (30s) ──→ cache + return
  │  │  │         │ fail
  │  │  │         ▼
  │  │  │  SharedPreferences (<1h old) ──→ return
  │  │  │         │ miss/stale
  │  │  │         ▼
  │  │  │      throw Exception
```

## Nostr Event

The daemon publishes a NIP-33 addressable event:

- **Kind:** `30078`
- **d tag:** `"mostro-rates"`
- **Content:** `{"BTC": {"USD": 50000.0, "EUR": 45000.0, ...}}`
- **Pubkey:** Mostro instance signing key

## Security

The client verifies event origin by comparing `event.pubkey == settings.mostroPublicKey` before parsing rates. This prevents price manipulation attacks from malicious actors publishing fake events via untrusted relays.

## Files

| File | Description |
|------|-------------|
| `lib/services/nostr_exchange_service.dart` | Main service: Nostr → HTTP → cache fallback |
| `lib/shared/providers/exchange_service_provider.dart` | Provider wiring (updated) |
| `test/services/nostr_exchange_service_test.dart` | Unit tests for rate parsing |

## Configuration

No new configuration needed. The service uses:
- `settings.mostroPublicKey` — to verify event pubkey matches the connected Mostro instance
- The same relay list configured for Mostro orders

## References

- [Mostro daemon PR #685](https://github.com/MostroP2P/mostro/pull/685)
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
- [Issue #550](https://github.com/MostroP2P/mobile/issues/550)
