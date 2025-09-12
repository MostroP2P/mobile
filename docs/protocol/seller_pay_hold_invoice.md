# Seller pays hold invoice

When the seller is the maker and the order was taken by a buyer, Mostro will send to the seller a message asking to pay the hold invoice, the rumor's content of the message will look like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "pay-invoice",
      "payload": {
        "payment_request": [
          {
            "id": "<Order Id>",
            "kind": "sell",
            "status": "waiting-payment",
            "amount": 7851,
            "fiat_code": "VES",
            "fiat_amount": 100,
            "payment_method": "face to face",
            "premium": 1,
            "created_at": 1698937797
          },
          "lnbcrt78510n1pj59wmepp50677g8tffdqa2p8882y0x6newny5vtz0hjuyngdwv226nanv4uzsdqqcqzzsxqyz5vqsp5skn973360gp4yhlpmefwvul5hs58lkkl3u3ujvt57elmp4zugp4q9qyyssqw4nzlr72w28k4waycf27qvgzc9sp79sqlw83j56txltz4va44j7jda23ydcujj9y5k6k0rn5ms84w8wmcmcyk5g3mhpqepf7envhdccp72nz6e"
        ]
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

After the hold invoice is paid and the buyer already sent the invoice to receive the sats, Mostro will send a new message to seller with the following rumor's content:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "buyer-took-order",
      "payload": {
        "order": {
          "id": "<Order Id>",
          "kind": "sell",
          "status": "active",
          "amount": 7851,
          "fiat_code": "VES",
          "fiat_amount": 100,
          "payment_method": "face to face",
          "premium": 1,
          "master_buyer_pubkey": "<Buyer's trade pubkey>",
          "master_seller_pubkey": "<Seller's trade pubkey>",
          "buyer_invoice": null,
          "created_at": 1698937797
        }
      }
    }
  },
  "<index N signature of the sha256 hash of the serialized first element of content>"
]
```

Mostro also send a message to the buyer, this way they can both write to each other in private, this message would look like this:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "hold-invoice-payment-accepted",
      "payload": {
        "order": {
          "id": "<Order Id>",
          "kind": "sell",
          "status": "active",
          "amount": 7851,
          "fiat_code": "VES",
          "fiat_amount": 100,
          "payment_method": "face to face",
          "premium": 1,
          "master_buyer_pubkey": "<Buyer's trade pubkey>",
          "master_seller_pubkey": "<Seller's trade pubkey>",
          "buyer_invoice": null,
          "created_at": 1698937797
        }
      }
    }
  },
  null
]
```

## If the buyer didn't sent the invoice yet

Mostro send this message to the seller:

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

And this message to the buyer:

```json
{
  "order": {
    "version": 1,
    "id": "<Order Id>",
    "action": "add-invoice",
    "payload": {
      "order": {
        "id": "<Order Id>",
        "kind": "sell",
        "status": "waiting-buyer-invoice",
        "amount": 7851,
        "fiat_code": "VES",
        "fiat_amount": 100,
        "payment_method": "face to face",
        "premium": 1,
        "created_at": 1698937797
      }
    }
  }
}
```

Now buyer sends the invoice to Mostro:

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

And both parties receives each other pubkeys to start a direct conversation.
