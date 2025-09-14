# Taking a buy range order

If the order fiat amount is a range like `10-20` the seller must indicate a fiat amount to take the order, seller will send a message in a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "take-buy",
      "trade_index": 1,
      "payload": {
        "amount": 15
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

## Mostro response

Response is the same as we explained in the [Taking a buy order](./take_buy.md) section.
