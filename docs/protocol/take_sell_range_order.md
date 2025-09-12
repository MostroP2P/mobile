# Taking a sell range order

If the order fiat amount is a range like `10-20` the buyer must indicate a fiat amount to take the order, buyer will send a message in a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "take-sell",
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

In order to continue the buyer needs to send a lightning network invoice to Mostro, in this case the amount of the order is `0`, so Mostro will need to calculate the amount of sats for this order, then Mostro will send back a message asking for a LN invoice indicating the correct amount of sats that the invoice should have, here the rumor's content of the message:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "add-invoice",
      "payload": {
        "order": {
          "id": "<Order Id>",
          "amount": 7851,
          "fiat_code": "VES",
          "min_amount": 10,
          "max_amount": 20,
          "fiat_amount": 15,
          "payment_method": "face to face",
          "premium": 1,
          "master_buyer_pubkey": null,
          "master_seller_pubkey": null,
          "buyer_invoice": null,
          "created_at": null,
          "expires_at": null
        }
      }
    }
  },
  null
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
      ["fa", "15"],
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

## Using a lightning address

The buyer can use a [lightning address](https://github.com/andrerfneves/lightning-address) to receive funds and avoid to create and send lightning invoices on each trade, with a range order we set the fiat amount as the third element of the `payment_request` array, to acomplish this the buyer will send a message in a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "take-sell",
    "payload": {
      "payment_request": [null, "mostro_p2p@ln.tips", 15]
    }
  }
}
```
