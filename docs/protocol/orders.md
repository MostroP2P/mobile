# Request order details

Clients can request detailed information for existing orders by sending a nip59 Gift wrap message with the action `orders`. This is useful for refreshing stale UI state or restoring a session from the mnemonic seed on a new device.

## Request message

The client sends a message where the payload object includes an `ids` array of order IDs. At least one ID must be provided, and Mostro may reject the request if the array exceeds its configured limits.

```json
[
  {
    "order": {
      "version": 1,
      "request_id": 8721,
      "action": "orders",
      "payload":  {
        "ids": [
          "c7dba9db-f13f-4c3f-a77f-3b82e43c2b1a",
          "751bc178-801a-4cc4-983c-68682e6fb6af"
        ]
      }
    }
  },
  null
]
```

Field:
- `ids`: Array of order ids exactly as published in the order event `d` tag.

The client only can request their own orders; mostrod will not provide information about any ID if it does not belong to the requesting party.

## Mostro response

Mostro replies with the same action and includes a structured payload describing each order that could be resolved, here is how the message look like:

```json
[
  {
    "order": {
      "version": 1,
      "request_id": 8721,
      "action": "orders",
      "payload": {
        "orders": [
          {
            "id": "c7dba9db-f13f-4c3f-a77f-3b82e43c2b1a",
            "kind": "sell",
            "status": "active",
            "amount": 3307,
            "fiat_code": "ARS",
            "min_amount": 1000,
            "max_amount": 5000,
            "fiat_amount": 5000,
            "payment_method": "Mercado Pago,Lemon",
            "premium": 2,
            "buyer_trade_pubkey": "<trade pubkey>",
            "seller_trade_pubkey": "<trade pubkey>",
            "created_at": 1758889527,
            "expires_at": 1758975927
          },
          {
            "id": "751bc178-801a-4cc4-983c-68682e6fb6af",
            "kind": "sell",
            "status": "fiat-sent",
            "amount": 1201,
            "fiat_code": "ARS",
            "min_amount": null,
            "max_amount": null,
            "fiat_amount": 2000,
            "payment_method": "MODO",
            "premium": 0,
            "buyer_trade_pubkey": "<trade pubkey>",
            "seller_trade_pubkey": "<trade pubkey>",
            "created_at": 1759168820,
            "expires_at": 1759255220
          }
        ]
      }
    }
  },
  null
]
```

Orders that are missing or unauthorized for the requesting user are not listed in the orders array.

## Limits and rate control

Mostrod enforces per-request limits to protect the daemon. Common policies include a `max_orders_per_response` cap (for example, 20 orders) and a rolling request quota per pubkey.

When a response is truncated because too many ids were requested, Mostrod returns only the first allowed ids. Clients should re-issue the call with the remaining ids after respecting the rate limits.

When a user exceeds the allowed request rate, Mostrod can answer with an error action such as `too-many-requests`. Implementations should surface these conditions to the user and back off accordingly.