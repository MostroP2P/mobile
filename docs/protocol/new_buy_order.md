# Creating a new buy order

To create a new buy order the user should send a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "action": "new-order",
      "trade_index": 1,
      "payload": {
        "order": {
          "kind": "buy",
          "status": "pending",
          "amount": 0,
          "fiat_code": "VES",
          "fiat_amount": 100,
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

The nostr event will look like this:

```json
{
  "id": "<Event id>",
  "kind": 1059,
  "pubkey": "<Buyer's ephemeral pubkey>",
  "content": "<sealed-rumor-content>",
  "tags": [["p", "Mostro's pubkey"]],
  "created_at": 1234567890,
  "sig": "<Signature of ephemeral pubkey>"
}
```

## Confirmation message

Mostro will send back a nip59 event as a confirmation message, the content of the rumor looks like the following:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order id>",
      "action": "new-order",
      "payload": {
        "order": {
          "id": "<Order id>",
          "kind": "buy",
          "status": "pending",
          "amount": 0,
          "fiat_code": "VES",
          "fiat_amount": 100,
          "payment_method": "face to face",
          "premium": 1,
          "master_buyer_pubkey": null,
          "master_seller_pubkey": null,
          "buyer_invoice": null,
          "created_at": 1698870173
        }
      }
    }
  },
  null
]
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
      ["k", "buy"],
      ["f", "VES"],
      ["s", "pending"],
      ["amt", "0"],
      ["fa", "100"],
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

After a seller takes this order Mostro will request an invoice from the buyer, Mostro will pay the buyer's invoice when the seller releases the funds.

## Creating the order with a lightning invoice

There are two ways where the buyer can create the order adding the invoice:

1. If the buyer already knows the amount, e.g. buyer wants to buy 15000 sats with 10 euros, in this case the buyer knows from the beginning that the invoice should have amount 15000 - Mostro's fee, instead of the user doing the calculation, the client must do it and in some cases create the invoice with the right amount.

2. If the buyer don't know the amount, e.g. buyer wants to buy sats with 10 euros, in this case the buyer can add an amountless invoice and Mostro will pay it with the market price amount - Mostro's fee automatically.
