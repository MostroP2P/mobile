# Listing Disputes

Mostro publishes new disputes with event kind `38386` and status `initiated`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703016565,
    "kind": 38386,
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

Clients can query these events by nostr event kind `38386`, nostr event author, dispute status (`s`), type (`z`)
