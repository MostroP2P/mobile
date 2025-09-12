# Taking a buy order

To take an order the seller will send to Mostro a message with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "take-buy",
      "trade_index": 1,
      "payload": null
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

The event to send to Mostro would look like this:

```json
{
  "id": "<Event id>",
  "kind": 1059,
  "pubkey": "<Seller's ephemeral pubkey>",
  "content": "<sealed-rumor-content>",
  "tags": [["p", "Mostro's pubkey"]],
  "created_at": 1234567890,
  "sig": "<Signature of ephemeral pubkey>"
}
```

## Mostro response

Mostro respond to the seller with a message with the following content:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "pay-invoice",
    "payload": {
      "payment_request": [
        {
          "id": "<Order Id>",
          "kind": "buy",
          "status": "waiting-payment",
          "amount": 7851,
          "fiat_code": "VES",
          "fiat_amount": 100,
          "payment_method": "face to face",
          "premium": 1,
          "created_at": 1698957793
        },
        "lnbcrt78510n1pj59wmepp50677g8tffdqa2p8882y0x6newny5vtz0hjuyngdwv226nanv4uzsdqqcqzzsxqyz5vqsp5skn973360gp4yhlpmefwvul5hs58lkkl3u3ujvt57elmp4zugp4q9qyyssqw4nzlr72w28k4waycf27qvgzc9sp79sqlw83j56txltz4va44j7jda23ydcujj9y5k6k0rn5ms84w8wmcmcyk5g3mhpqepf7envhdccp72nz6e"
      ]
    }
  }
}
```

Mostro updates the addressable event with `d` tag `<Order Id>` to change the status to `in-progress`:

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
      ["s", "in-progress"],
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

And send a message to the buyer with the following content:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "waiting-seller-to-pay",
    "payload": null
  }
}
```

## Seller pays LN invoice

After seller pays the hold invoice Mostro send a message to the seller with the following content:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "waiting-buyer-invoice",
    "payload": null
  }
}
```
Mostro sends a message to the buyer with the following content:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "add-invoice",
    "payload": {
      "order": {
        "id": "<Order Id>",
        "status": "waiting-buyer-invoice",
        "amount": 7851,
        "fiat_code": "VES",
        "fiat_amount": 100,
        "payment_method": "face to face",
        "premium": 1,
        "created_at": null
      }
    }
  }
}
```

## Buyer sends LN invoice

Buyer sends the LN invoice to Mostro.

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "add-invoice",
    "payload": {
      "payment_request": [
        null,
        "lnbcrt78510n1pj59wmepp50677g8tffdqa2p8882y0x6newny5vtz0hjuyngdwv226nanv4uzsdqqcqzzsxqyz5vqsp5skn973360gp4yhlpmefwvul5hs58lkkl3u3ujvt57elmp4zugp4q9qyyssqw4nzlr72w28k4waycf27qvgzc9sp79sqlw83j56txltz4va44j7jda23ydcujj9y5k6k0rn5ms84w8wmcmcyk5g3mhpqepf7envhdccp72nz6e"
      ]
    }
  }
}
```

Now both parties have an `active` order and they can keep going with the trade.