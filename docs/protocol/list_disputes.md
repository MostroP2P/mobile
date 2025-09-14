# Listing Disputes

Mostro publishes new disputes with event kind `38383` and status `initiated`:

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

Clients can query this events by nostr event kind `38383`, nostr event author, dispute status (`s`), type (`z`)
