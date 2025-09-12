# Restore Session

To restore a session from the mnemonic seed on a new device (e.g., moving from mobile to desktop), the client sends a `restore-session` message. Mostro will respond with the relevant orders and disputes so the client can rebuild the session state using the same `trade_index` values.

## Request

Client sends a Gift wrap Nostr event to Mostro with the following rumor's content:

```json
{
  "restore": {
    "version": 1,
    "action": "restore-session",
    "payload": null
  }
}
```

## Response

Mostro will respond with a message containing all non-finalized orders (e.g., statuses such as `pending`, `active`, `fiat-sent`, `waiting-buyer-invoice`, `waiting-payment`, `settled-hold-invoice`) and any active disputes. The response format will be:

```json
{
  "restore": {
    "version": 1,
    "action": "restore-session",
    "payload": {
      "restore_data": {
        "orders": [
          {
            "id": "<Order Id>",
            "trade_index": 1,
            "status": "pending"
          },
          {
            "id": "<Order Id>",
            "trade_index": 2,
            "status": "active"
          },
          {
            "id": "<Order Id>",
            "trade_index": 3,
            "status": "fiat-sent"
          }
        ],
        "disputes": [
          {
            "dispute_id": "<Dispute Id>",
            "order_id": "<Order Id>",
            "trade_index": 4,
            "status": "initiated"
          }
        ]
      }
    }
  }
}
```

### Fields

* `restore_data`: Wrapper object that contains the session recovery data.
* `restore_data.orders`: An array of active or ongoing orders with their `id`, `trade_index`, and current `status`.
* `restore_data.disputes`: An array of ongoing disputes with `dispute_id`, the associated `order_id`, and `trade_index` and current `status` of the dispute.

## Example Use Case

A user has the following:

* Two `pending` orders (trade index 1 and 2)
* One `active` order (trade index 3)
* One active dispute (trade index 4)

When switching to desktop, after restoring the mnemonic, the client sends `restore-session` and receives:

```json
{
  "restore": {
    "version": 1,
    "action": "restore-session",
    "payload": {
      "restore_data": {
        "orders": [
          { "id": "abc-123", "trade_index": 1, "status": "pending" },
          { "id": "def-456", "trade_index": 2, "status": "pending" },
          { "id": "ghi-789", "trade_index": 3, "status": "active" },
          { "id": "xyz-999", "trade_index": 4, "status": "dispute" }
        ],
        "disputes": [
          { "dispute_id": "dis-001", "order_id": "xyz-999", "trade_index": 4, "status": "initiated" }
        ]
      }
    }
  }
}
```
