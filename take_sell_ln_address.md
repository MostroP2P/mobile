# Taking a sell order with a lightning address

The buyer can use a [lightning address](https://github.com/andrerfneves/lightning-address) to receive funds and avoid to manually create and send lightning invoices on each trade, to acomplish this the buyer will send a message in a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "take-sell",
      "trade_index": 1,
      "payload": {
        "payment_request": [null, "mostro_p2p@ln.tips"]
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

The event to send to Mostro would look like this:

```json
{
  "id": "<Event id>",
  "kind": 1059,
  "pubkey": "<Ephemeral pubkey>",
  "content": "<sealed-rumor-content>",
  "tags": [["p", "Mostro's pubkey"]],
  "created_at": 1234567890,
  "sig": "<Signature of ephemeral pubkey>"
}
```

## Mostro response

Mostro send a Gift wrap Nostr event to the buyer with a wrapped `order` in the rumor's content, it would look like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "waiting-seller-to-pay",
      "payload": null
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

Mostro updates the addressable event with `d` tag `<Order Id>` to change the status to `in-progress`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1702549437,
    "kind": 38383,
    "tags": [
      ["d", "<Order Id>"],
      ["k", "sell"],
      ["f", "VES"],
      ["s", "in-progress"],
      ["amt", "7851"],
      ["fa", "100"],
      ["pm", "face to face"],
      ["premium", "1"],
      ["network", "mainnet"],
      ["layer", "lightning"],
      ["expiration", "1719391096"],
      ["y", "mostro"],
      ["z", "order"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```
