# Taking a sell order

If the order amount is `0` the buyer doesn't know the exact amount to create the invoice, buyer will send a message in a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "take-sell",
      "trade_index": 1,
      "payload": null
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
          "fiat_amount": 100,
          "payment_method": "face to face",
          "premium": 1,
          "buyer_pubkey": null,
          "seller_pubkey": null
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
      ["fa", "100"],
      ["pm", "face to face", "bank transfer"],
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

## Buyer sends LN invoice

The buyer sends a Gift wrap Nostr event to Mostro with the lightning invoice, the action should be the same the buyer just received in the last message from Mostro (`add-invoice`), here the rumor's content of the event for an invoice with no amount:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "add-invoice",
      "payload": {
        "payment_request": [
          null,
          "lnbcrt1pn9dvx0pp5935mskms2uf8wx90m8dlr60ytwn5vxy0e65ls42h7y7exweyvekqdqqcqzzsxqyz5vqsp5xjmllv4ta7jkuc5nfgqp8qjc3amzfewmlycpkkggr7q2y5mjfldq9qyyssqncpf3vm8hwujutqc99f0vy45zh8es54mn6u99q9t6rwm0q80dxszskzrp24y46lxqkc7ly9p80t6lalc8x8xhsn49yhy70a7wqyygugpv7chqs",
          3922
        ]
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

If the invoice includes an amount, the last element of the `payment_request` array should be set to `null`.

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
  null
]
```

