# Settle order

An admin can settle an order, most of the time this is done when admin is solving a dispute, for this the admin will need to send an `order` message to Mostro with action `admin-settle` with the `id` of the order like this:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "admin-settle",
    "payload": null
  }
}
```

## Mostro response

Mostro will send this message to the both parties buyer/seller and to the admin:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "admin-settled",
    "payload": null
  }
}
```

## Mostro updates addressable dispute event

Mostro updates the addressable dispute event with status `settled`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "098e8622eae022a79bc793984fccbc5ea3f6641bdcdffaa031c00d3bd33ca5a0",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703274022,
    "kind": 38383,
    "tags": [
      ["d", "efc75871-2568-40b9-a6ee-c382d4d6de01"],
      ["s", "settled"],
      ["y", "mostro"],
      ["z", "dispute"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```

## Payment of the buyer's invoice

At this point Mostro is trying to pay the buyer's invoice, right after complete the payment Mostro will update the status of the order addressable event to `success`:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "6170892aca6a73906142e58a9c29734d49b399a3811f6216ce553b4a77a8a11e",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703274032,
    "kind": 38383,
    "tags": [
      ["d", "<Order Id>"],
      ["k", "sell"],
      ["f", "VES"],
      ["s", "success"],
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
