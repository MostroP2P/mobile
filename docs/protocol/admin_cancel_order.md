# Cancel order

An admin can cancel an order, most of the time this is done when admin is solving a dispute, for this the admin will need to send an `order` message to Mostro with action `admin-cancel` with the `id` of the order like this:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "admin-cancel",
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
    "action": "admin-canceled",
    "payload": null
  }
}
```

## Mostro updates addressable events

Mostro will publish two addressable events, one for the order to update the status to `canceled`, this means that the hold invoice was canceled and the seller's funds were returned:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "3d74ce3f10096d163603aa82beb5778bd1686226fdfcfba5d4c3a2c3137929ea",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1703260182,
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

The second event updates the addressable dispute event with status `seller-refunded`:
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
      ["s", "seller-refunded"],
      ["y", "mostro"],
      ["z", "dispute"]
    ],
    "content": "",
    "sig": "<Mostro's signature>"
  }
]
```
