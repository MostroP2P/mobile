## Overview

In order to have a shared order's book, Mostro daemon send [Addressable Events](https://github.com/nostr-protocol/nips/blob/master/01.md#kinds) with `38383` as event `kind`, you can find more details about that specific event [here](./order_event.md)

## The Message

All **_messages_** from/to Mostro should be [Gift wrap Nostr events](https://github.com/nostr-protocol/nips/blob/master/59.md), the `content` of the `rumor` event is an `array`, the `first element should be a JSON-serialized string` (with no white space or line breaks), the `second element is the signature` of the sha256 hash of the serialized first element, here the structure of the first element:

- [Wrapper](https://docs.rs/mostro-core/latest/mostro_core/message/enum.Message.html): Wrapper of the **_Message_**
  - <`version` integer>: Version of the protocol, currently `1`
  - [`id` integer]: (optional) Wrapper Id
  - [`request_id` integer]: (optional) Mostro daemon should send back this same id in the response
  - [`trade_index` integer]: (optional) This field is used by users who wants to maintain reputation, it should be the index of the trade in the user's trade history
  - <`action` string>: [Action](https://docs.rs/mostro-core/latest/mostro_core/message/enum.Action.html) to be performed by Mostro daemon
  - [`payload` string]: (optional) [Payload](https://docs.rs/mostro-core/latest/mostro_core/message/enum.Content.html) of the message, it should be a JSON-serialized string. The content of this field depends on the `action` field.

Here an example of a `new-order` order **_message_**:

```json
{
  "order": {
    "version": 1,
    "id": "<Order id>",
    "request_id": 123456,
    "trade_index": 1,
    "action": "new-order",
    "payload": {
      "order": {
        "id": "<Order id>",
        "kind": "sell",
        "status": "pending",
        "amount": 0,
        "fiat_code": "VES",
        "fiat_amount": 100,
        "payment_method": "face to face",
        "premium": 1,
        "created_at": 1698870173
      }
    }
  }
}
```
