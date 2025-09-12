# User rating

After a successful trade Mostro send a Gift wrap Nostr event to both parties to let them know they can rate each other, here an example how the message look like:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "rate",
    "payload": null
  }
}
```

After a Mostro client receive this message, the user can rate the other party, the rating is a number between 1 and 5, to rate the client must receive user's input and create a new Gift wrap Nostr event to send to Mostro with this content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "rate-user",
      "payload": {
        "rating_user": 5 // User input
      }
    }
  },
  null
]
```

## Confirmation message

If Mostro received the correct message, it will send back a confirmation message to the user with the action `rate-received`:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "rate-received",
    "payload": {
      "rating_user": 5
    }
  }
}
```

Mostro updates the addressable rating event, in this event the `d` tag will be the user pubkey `<Seller's trade pubkey>` and looks like this:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1702637077,
    "kind": 38383,
    "tags": [
      ["d", "<Seller's trade pubkey>"],
      ["total_reviews", "1"],
      ["total_rating", "2"],
      ["last_rating", "1"],
      ["max_rate", "2"],
      ["min_rate", "5"],
      ["z", "rating"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```
