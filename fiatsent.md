# Fiat sent

After the buyer sends the fiat money to the seller, the buyer should send a message in a Gift wrap Nostr event to Mostro indicating that the fiat money was sent, message in the first element of the rumor's content would look like this:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "fiat-sent",
    "payload": null
  }
}
```

## When the maker is the buyer on a range order

In most of the cases after complete a range order, a child order needs to be created, the client is rotating keys favoring privacy so Mostro can't know which would be the next `trade pubkey` of the maker, to solve this the client needs to send `trade pubkey` and `trade index` of the child order on the `fiat-sent` message, the message looks like this:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "fiat-sent",
    "payload": {
      "next_trade": ["<trade pubkey>", <trade index>]
    }
  }
}
```

## Mostro response

Mostro send messages to both parties confirming `fiat-sent` action and sending again the counterpart pubkey, here an example of the message to the buyer:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "fiat-sent-ok",
    "payload": {
      "peer": {
        "pubkey": "<Seller's trade pubkey>"
      }
    }
  }
}
```

And here an example of the message from Mostro to the seller:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "pubkey": "<Seller's trade pubkey>",
    "action": "fiat-sent-ok",
    "payload": {
      "peer": {
        "pubkey": "<Buyer's trade pubkey>"
      }
    }
  }
}
```
