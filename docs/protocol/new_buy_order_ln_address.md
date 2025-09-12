# Creating a new order

Creating buy order with a [lightning address](https://github.com/andrerfneves/lightning-address) would make the process way faster and easy going, to acomplish the buyer should send a Gift wrap Nostr event to Mostro with the following rumor's content:

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
          "payment_method": "face to face,mobile",
          "premium": 1,
          "buyer_invoice": "mostro_p2p@ln.tips",
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

Mostro will send back a nip59 event as a confirmation message to the user like the following:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "new-order",
    "payload": {
      "order": {
        "id": "<Order Id>",
        "kind": "buy",
        "status": "pending",
        "amount": 0,
        "fiat_code": "VES",
        "fiat_amount": 100,
        "payment_method": "face to face,mobile",
        "premium": 1,
        "master_buyer_pubkey": null,
        "master_seller_pubkey": null,
        "buyer_invoice": "mostro_p2p@ln.tips",
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
      ["d", "<Order Id>"],
      ["k", "buy"],
      ["f", "VES"],
      ["s", "pending"],
      ["amt", "0"],
      ["fa", "100"],
      ["pm", "face to face", "mobile"],
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

After a seller takes this order Mostro will not ask for an invoice to the buyer, Mostro will get the buyer's invoice and paid it when the seller releases the funds.
