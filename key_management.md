# Keys management

_It is required to read [NIP-59 (gift wrap)](https://github.com/nostr-protocol/nips/blob/master/59.md) and [NIP-06](https://github.com/nostr-protocol/nips/blob/master/06.md) to fully understand this document_

Mostro clients should implement nip59 which creates newly fresh keys on each message to Mostro, but the key management is a bit more complex, here we will explain how to manage keys in Mostro clients.

### Objectives:

- Facilitate portability by using a deterministic key generation mechanism based on NIP-06.
- Prevent users from mistakenly entering key material already used in other Nostr social media apps.
- Rotate keys for every trade.

When a user started a Mostro client for first time, the client should create a new mnemonic seed phrase which is the only information users will need to share with other client to have the same `Mostro session`. Mostro clients should use the derivation path `m/44'/1237'/38383'/0/0`.

Clients will always use the first key (zero) `m/44'/1237'/38383'/0/0` to identify itself with mostrod, users who wants to maintain reputation can send an event to Mostro signed with the `zero` key, the identity key, used to update their rating, for every new order created or taken the client will start deriving new keys from `m/44'/1237'/38383'/0/1`, users who don't want to maintain reputation simply don't send the identity key to mostrod, let's see it in more detail with an example:

- Alice starts a Mostro client for first time, at that moment the client creates a new mnemonic seed phrase and derive two keys, the identity key (index `0`) and the next trade key with index `1` `m/44'/1237'/38383'/0/1`, we will use identiy key to sign the gift wrap seal event and the trade key to sign the first element of the content of the rumor event.

- Alice wants to buy some bitcoin and take a sell order, the client send a message in a Gift wrap Nostr event to mostrod with the seal signed with index `0` key and in the rumor we should demostrate we own the trade key (index `1`), let's see a `take-sell` example in an unencrypted gift wrap event:

```json
// external wrap layer
{
  "id": "<id>",
  "kind": 1059,
  "pubkey": "<Buyer's ephemeral pubkey>",
  "content": {
    // seal
    "id": "<seal's id>",
    "pubkey": "<index 0 pubkey (identity key)>",
    "content": {
      // rumor
      "id": "<rumor's id>",
      "pubkey": "<Index 1 pubkey (trade key)>",
      "kind": 1,
      "content": [
        {
          "order": {
            "version": 1,
            "id": "<Order Id>",
            "trade_index": 1,
            "action": "take-sell",
            "payload": null
          }
        },
        "<index 1 signature of the sha256 hash of the serialized first element of content>"
      ],
      "created_at": 1691518405,
      "tags": []
    },
    "kind": 13,
    "created_at": 1686840217,
    "tags": [],
    "sig": "<index 0 pubkey (identity key) signature>"
  },
  "tags": [["p", "<Mostro's pubkey>"]],
  "created_at": 1234567890,
  "sig": "<Buyer's ephemeral pubkey signature>"
}
```

- After finish the deal the [rate](./user_rating.md) each other.

Then Alice wants to create a new buy order:

- The client derives the next key, new key is index `2` (`m/44'/1237'/38383'/0/2`) and send a message in a Gift wrap Nostr event to mostrod with the seal signed with index `0` key, but let's see the complete example with a full unencrypted gift wrap:

```json
// external wrap layer
{
  "id": "<id>",
  "kind": 1059,
  "pubkey": "<Buyer's ephemeral pubkey>",
  "content": {
    // seal
    "id": "<seal's id>",
    "pubkey": "<index 0 pubkey (identity key)>",
    "content": {
      // rumor
      "id": "<rumor's id>",
      "pubkey": "<Index 2 pubkey (trade key)>",
      "kind": 1,
      "content": [
        {
          "order": {
            "version": 1,
            "trade_index": 2,
            "action": "new-order",
            "payload": {
              "order": {
                "kind": "buy",
                "status": "pending",
                "amount": 0,
                "fiat_code": "VES",
                "fiat_amount": 100,
                "payment_method": "face to face",
                "premium": 1,
                "created_at": 1691518405
              }
            }
          }
        },
        "<index 2 signature of the sha256 hash of the serialized first element of content>"
      ],
      "created_at": 1691518405,
      "tags": []
    },
    "kind": 13,
    "created_at": 1686840217,
    "tags": [],
    "sig": "<index 0 pubkey (identity key) signature>"
  },
  "tags": [["p", "<Mostro's pubkey>"]],
  "created_at": 1234567890,
  "sig": "<Buyer's ephemeral pubkey signature>"
}
```

Now Alice waits for some seller to take her order, mostrod will show Alice's reputation but not Alice pubkey.

### Full privacy mode

Clients must offer a more private version where the client never send the identity key to mostrod, in that case mostrod can't link orders to users, the tradeoff is that users who choose this option cannot have a reputation, let's see a `take-sell` example in an unencrypted gift wrap event:

```json
// external wrap layer
{
  "id": "<id>",
  "kind": 1059,
  "pubkey": "<Buyer's ephemeral pubkey>",
  "content": {
    // seal
    "id": "<seal's id>",
    "pubkey": "<index N pubkey (trade key)>",
    "content": {
      // rumor
      "id": "<rumor's id>",
      "pubkey": "<index N pubkey (trade key)>",
      "kind": 1,
      "content": [
        {
          "order": {
            "version": 1,
            "id": "<Order Id>",
            // "trade_index": 1, // not needed
            "action": "take-sell",
            "payload": null
          }
        },
        null
      ],
      "created_at": 1691518405,
      "tags": []
    },
    "kind": 13,
    "created_at": 1686840217,
    "tags": [],
    "sig": "<index N pubkey (trade key) signature>"
  },
  "tags": [["p", "<Mostro's pubkey>"]],
  "created_at": 1234567890,
  "sig": "<Buyer's ephemeral pubkey signature>"
}
```
