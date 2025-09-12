# Cancel Order

A user can cancel an order created by himself and with status `pending` sending action `cancel`, the rumor's content of the message will look like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "cancel",
      "payload": null
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

## Mostro response

Mostro will send a message with action `cancel` confirming the order was canceled, here an example of rumor's content of the message:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "canceled",
      "payload": null
    }
  },
  null
]
```

Mostro updates the parameterized replaceable event with `d` tag `<Order Id>` to change the status to `canceled`:

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
      ["s", "canceled"],
      ["amt", "7851"],
      ["fa", "100"],
      ["pm", "face to face"],
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

## Cancel cooperatively

A user can cancel an `active` order, but will need the counterparty to agree, let's look at an example where the seller initiates a cooperative cancellation:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "cancel",
    "payload": null
  }
}
```

Mostro will send this message to the seller:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "cooperative-cancel-initiated-by-you",
    "payload": null
  }
}
```

And this message to the buyer:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "cooperative-cancel-initiated-by-peer",
    "payload": null
  }
}
```

The buyer can accept the cooperative cancellation sending this message:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "cancel",
    "payload": null
  }
}
```

And Mostro will send this message to both parties:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "cooperative-cancel-accepted",
    "payload": null
  }
}
```
Mostro updates the parameterized replaceable event with `d` tag `<Order Id>` to change the status to `canceled`:

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
      ["s", "canceled"],
      ["amt", "7851"],
      ["fa", "100"],
      ["pm", "face to face"],
      ["premium", "1"],
      ["y", "mostro"],
      ["z", "order"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```
