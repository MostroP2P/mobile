# Peer-to-peer Order events. NIP-69

## Abstract

Peer-to-peer (P2P) platforms have seen an upturn in recent years, while having more and more options is positive, in the specific case of p2p, having several options contributes to the liquidity split, meaning sometimes there's not enough assets available for trading. If we combine all these individual solutions into one big pool of orders, it will make them much more competitive compared to centralized systems, where a single authority controls the liquidity.

This NIP defines a simple standard for peer-to-peer order events, which enables the creation of a big liquidity pool for all p2p platforms participating.

## The event

Events are [addressable events](https://github.com/nostr-protocol/nips/blob/master/01.md#kinds) and use `38383` as event kind, a p2p event look like this:

```json
{
  "id": "<Event id>",
  "pubkey": "<Mostro's pubkey>",
  "created_at": 1702548701,
  "kind": 38383,
  "tags": [
    ["d", "<Order Id>"],
    ["k", "sell"],
    ["f", "VES"],
    ["s", "pending"],
    ["amt", "0"],
    ["fa", "100"],
    ["pm", "face to face", "bank transfer"],
    ["premium", "1"],
    [
      "rating",
      "{\"total_reviews\":1,\"total_rating\":3.0,\"last_rating\":3,\"max_rate\":5,\"min_rate\":1}"
    ],
    ["source", "https://t.me/p2plightning/xxxxxxx"],
    ["network", "mainnet"],
    ["layer", "lightning"],
    ["name", "Nakamoto"],
    ["g", "<geohash>"],
    ["bond", "0"],
    ["expiration", "1719391096"],
    ["y", "lnp2pbot"],
    ["z", "order"]
  ],
  "content": "",
  "sig": "<Mostro's signature>"
}
```

## Tags

- `d` < Order ID >: A unique identifier for the order.
- `k` < Order type >: `sell` or `buy`. This specifies the type of transaction in terms of bitcoin. "sell" means selling bitcoin, while "buy" indicates buying bitcoin.
- `f` < Currency >: The fiat asset being traded, using the [ISO 4217](https://en.wikipedia.org/wiki/ISO_4217) standard.
- `s` < Status >: `pending`, `canceled`, `in-progress`, `success`.
- `amt` < Amount >: The amount of Bitcoin to be traded, the amount is defined in satoshis, if `0` means that the amount of satoshis will be obtained from a public API after the taker accepts the order.
- `fa` < Fiat amount >: The fiat amount being traded, for range orders two values are expected, the minimum and maximum amount.
- `pm` < Payment method >: The payment method used for the trade, if the order has multiple payment methods, they should be separated by a comma.
- `premium` < Premium >: The percentage of the premium the maker is willing to pay.
- `source` [Source]: The source of the order, it can be a URL that redirects to the order.
- `rating` [Rating]: The rating of the maker, this document does not define how the rating is calculated, it's up to the platform to define it.
- `network` < Network >: The network used for the trade, it can be `mainnet`, `testnet`, `signet`, etc.
- `layer` < Layer >: The layer used for the trade, it can be `onchain`, `lightning`, `liquid`, etc.
- `name` [Name]: The name of the maker.
- `g` [Geohash]: The geohash of the operation, it can be useful in a face to face trade.
- `bond` [Bond]: The bond amount, the bond is a security deposit that both parties must pay.
- `expiration` < Expiration\>: The expiration date of the order ([NIP-40](https://github.com/nostr-protocol/nips/blob/master/40.md)).
- `y` < Platform >: The platform that created the order.
- `z` < Document >: `order`.

Mandatory tags are enclosed with `<tag>`, optional tags are enclosed with `[tag]`.

## Implementations

Currently implemented on the following platforms:

- [Mostro](https://github.com/MostroP2P/mostro)
- [@lnp2pBot](https://github.com/lnp2pBot/bot)
- [Robosats](https://github.com/RoboSats/robosats/pull/1362)

## This document is inspired on

- [Mostro protocol specification](https://mostro.network/protocol/)
- [Messages specification for peer 2 peer NIP proposal](https://github.com/nostr-protocol/nips/blob/8250274a22f4882f621510df0054fd6167c10c9e/31001.md)
- [n3xB](https://github.com/nobu-maeda/n3xb)
