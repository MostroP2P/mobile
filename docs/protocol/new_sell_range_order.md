# Creating a new sell range order

To create a new range order the user should send a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "action": "new-order",
      "trade_index": 1,
      "payload": {
        "order": {
          "kind": "sell",
          "status": "pending",
          "amount": 0,
          "fiat_code": "VES",
          "min_amount": 10,
          "max_amount": 20,
          "fiat_amount": 0,
          "payment_method": "face to face",
          "premium": 1,
          "created_at": 0
        }
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

Here we have two new fields, `min_amount` and `max_amount`, to define the range of the order. The `fiat_amount` field is set to 0 to indicate that the order is for a range of amounts.

When a taker takes the order, the amount will be set on the message.

## Confirmation message

Mostro will send back a nip59 event as a confirmation message to the user like the following:

```json
{
  "order": {
    "version": 1,
    "id": "<Order id>",
    "action": "new-order",
    "payload": {
      "order": {
        "id": "<Order id>",
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "VES",
        "min_amount": 10,
        "max_amount": 20,
        "fiat_amount": 0,
        "payment_method": "face to face",
        "premium": 1,
        "created_at": 1698870173
      }
    }
  }
}
```

Mostro publishes this order as an event kind `38383` with status `pending`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1702548701,
    "kind": 38383,
    "tags": [
      ["d", "<Order id>"],
      ["k", "sell"],
      ["f", "VES"],
      ["s", "pending"],
      ["amt", "0"],
      ["fa", "10", "20"],
      ["pm", "face to face"],
      ["premium", "1"],
      ["rating", "[\"rating\",{\"days\":10,\"total_rating\":4.5,\"total_reviews\":7}]"],
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
