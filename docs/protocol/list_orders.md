# Listing Orders

Mostro publishes new orders with event kind `38383` and status `pending`:

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
      ["k", "sell"],
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

Clients can query this events by nostr event kind `38383`, nostr event author, order status (`s`), order kind (`k`), order currency (`f`), type (`z`)
