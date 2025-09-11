# Release

After confirming the buyer sent the fiat money, the seller should send a message to Mostro indicating that sats should be delivered to the buyer, the message inside rumor's content will look like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "request_id": "123456",
      "action": "release",
      "payload": null
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

## Mostro response

Here an example of the Mostro response to the seller:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "request_id": "123456",
      "action": "hold-invoice-payment-settled",
      "payload": null
    }
  },
  null
]
```

And a message to the buyer to let him know that the sats were released:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "released",
      "payload": null
    }
  },
  null
]
```

## Buyer receives sats

Right after seller release sats Mostro will attempt to pay the buyer's lightning invoice. When the payment succeeds, Mostro will send a message to the buyer indicating that the purchase was completed:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "purchase-completed",
    "payload": null
  }
}
```

Mostro updates the addressable event with the `d` tag `<Order Id>` to change the status to `success`:

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
      ["s", "success"],
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

## Release a range order

If the order is a range order probably after release a child order would need to be created, Mostro can't know which would be the next `trade pubkey`, so the client of the maker must send this information, here how the message must look like:

```json
{
  "order": {
    "version": 1,
    "id": "4fd93fc9-e909-4fc9-acef-9976122b5dfa",
    "action": "release",
    "payload": {
      "next_trade": ["<trade pubkey>", <trade index>]
    }
  }
}
```

Mostro will send to the maker the newly child order created with the same `trade_index` received in the payload, if the maker is the buyer the `trade_index` would be the one sent in the payload of the `fiat-sent` message by the buyer, the `trade_index` will be used by the client to get the next key, the message will look like this:

```json
{
  "order": {
    "version": 1,
    "id": "4fd93fc9-e909-4fc9-acef-9976122b5dfa",
    "action": "new-order",
    "trade_index": <trade index>,
    "request_id": "123456",
    "payload": {
      "order": {
        "id": "4fd93fc9-e909-4fc9-acef-9976122b5dfa",
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "VES",
        "min_amount": <min amount>,
        "max_amount": <max amount>,
        "fiat_amount": 0,
        "payment_method": "face to face",
        "premium": 1,
        "created_at": 123456789,
        "expires_at": 123456789
      }
    }
  }
}
```
