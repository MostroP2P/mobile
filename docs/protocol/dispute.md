# Dispute

A use can start a dispute in an order with status `active` or `fiat-sent` sending action `dispute`, here is an example where the seller initiates a dispute:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "dispute",
      "payload": null
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

## Mostro response

Mostro will send this message to the seller:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "dispute-initiated-by-you",
      "payload": {
        "dispute": "<Dispute Id>"
      }
    }
  },
  null
]
```

And here is the message to the buyer:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "dispute-initiated-by-peer",
      "payload": {
        "dispute": "<Dispute Id>"
      }
    }
  },
  null
]
```

Mostro will not update the addressable event with `d` tag `<Order Id>` to change the status to `dispute`, this is because the order is still active, the dispute is just a way to let the admins and the other party know that there is a problem with the order.

## Mostro send a addressable event to show the dispute

Here is an example of the event sent by Mostro:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703016565,
    "kind": 38383,
    "tags": [
      ["d", "<Dispute Id>"],
      ["s", "initiated"],
      ["y", "mostro"],
      ["z", "dispute"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```

Mostro admin will see the dispute and can take it using the dispute `Id` from `d` tag, here how should look the message sent by the admin:

```json
{
  "dispute": {
    "version": 1,
    "id": "<Dispute Id>",
    "action": "admin-take-dispute",
    "payload": null
  }
}
```

Mostro will send a confirmation message to the admin with the order details:

```json
{
  "dispute": {
    "version": 1,
    "id": "<Dispute Id>",
    "action": "admin-took-dispute",
    "payload": {
      "order": {
        "id": "<Order Id>",
        "kind": "sell",
        "status": "active",
        "amount": 7851,
        "fiat_code": "VES",
        "fiat_amount": 100,
        "payment_method": "face to face",
        "premium": 1,
        "master_buyer_pubkey": "<Buyer's trade pubkey>",
        "master_seller_pubkey": "<Seller's trade pubkey>",
        "buyer_invoice": "lnbcrt11020n1pjcypj3pp58m3d9gcu4cc8l3jgkpfn7zhqv2jfw7p3t6z3tq2nmk9cjqam2c3sdqqcqzzsxqyz5vqsp5mew44wzjs0a58d9sfpkrdpyrytswna6gftlfrv8xghkc6fexu6sq9qyyssqnwfkqdxm66lxjv8z68ysaf0fmm50ztvv773jzuyf8a5tat3lnhks6468ngpv3lk5m7yr7vsg97jh6artva5qhd95vafqhxupyuawmrcqnthl9y",
        "created_at": 1698870173
      }
    }
  }
}
```

Then mostrod send messages to each trade participat, the buyer and seller for them to know the pubkey of the admin who took the dispute, that way the client can start listening events from that specific pubkey, by default clients should discard any messages received from any pubkey different than Mostro node or dispute solver, the message looks like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "admin-took-dispute",
      "payload": {
        "peer": {
          "pubkey": "<Solver's pubkey>"
        }
      }
    }
  },
  null
]
```

Also Mostro will broadcast a new addressable dispute event to update the dispute `status` to `in-progress`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703020540,
    "kind": 38383,
    "tags": [
      ["d", "<Dispute Id>"],
      ["s", "in-progress"],
      ["y", "mostro"],
      ["z", "dispute"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```
