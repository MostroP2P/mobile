# User rating

After a successful trade Mostro send a Gift wrap Nostr event to both parties to let them know they can rate each other, here an example how the message look like:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "rate",
      "payload": null
    }
  },
  null
]
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
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "rate-received",
      "payload": {
        "rating_user": 5
      }
    }
  },
  null
]
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
    "kind": 38384,
    "tags": [
      ["d", "<Seller's trade pubkey>"],
      ["total_reviews", "1"],
      ["total_rating", "2"],
      ["last_rating", "1"],
      ["max_rate", "5"],
      ["min_rate", "1"],
      ["days", "21"],
      ["y", "mostro"],
      ["z", "rating"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```

## Tags

- `d` < User trade pubkey >: The trade pubkey of the rated user.
- `total_reviews` < Total reviews >: The total number of reviews the user has received.
- `total_rating` < Total rating >: The overall reputation rating of the user.
- `last_rating` < Last rating >: The rating received in the most recent review.
- `max_rate` < Max rate >: The highest rating the user has received.
- `min_rate` < Min rate >: The lowest rating the user has received.
- `days` < Days >: The number of days since the user's first trade.
- `y` < Platform >: The platform that created the rating.
- `z` < Document >: `rating`.
