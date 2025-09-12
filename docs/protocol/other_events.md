# Other events published by Mostro

Each Mostro instance periodically publishes events with relevant information about its status, such as the code version it is using, the latest commit, the fees it charges, allowed exchange limits, the relays it publishes to, and much more. Below, we provide details on these events.

## Mostro Instance Status

This event contains specific data about a Mostro instance. The instance is identified by the `d` label.

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "kind": 38383
    "tags": [
      [
        "d",
        "<Mostro's pubkey>"
      ],
      [
        "mostro_version",
        "0.12.8"
      ],
      [
        "mostro_commit_hash",
        "1aac442058720c05954850bcffca6bcdfc87d150"
      ],
      [
        "max_order_amount",
        "1000000"
      ],
      [
        "min_order_amount",
        "100"
      ],
      [
        "expiration_hours",
        "1"
      ],
      [
        "expiration_seconds",
        "900"
      ],
      [
        "fee",
        "0.006"
      ],
      [
        "pow",
        "0"
      ],
      [
        "hold_invoice_expiration_window",
        "120"
      ],
      [
        "hold_invoice_cltv_delta",
        "144"
      ],
      [
        "invoice_expiration_window",
        "120"
      ],
      [
        "lnd_version",
        "0.18.4-beta commit=v0.18.4-beta"
      ],
      [
        "lnd_node_pubkey",
        "0220e4558a8d9af4988ef6c8def0e73b05403819e49b7fb2db79d322ac3be1547e"
      ],
      [
        "lnd_commit_hash",
        "ddeb8351684a611f6c27f16f09be75d5c039f08c"
      ],
      [
        "lnd_node_alias",
        "alice"
      ],
      [
        "lnd_chains",
        "bitcoin"
      ],
      [
        "lnd_networks",
        "regtest"
      ],
      [
        "lnd_uris",
        "0220e4558a8d9af4988ef6c8def0e73b05403819e49b7fb2db79d322ac3be1547e@172.26.0.2:9735"
      ],
      [
        "y",
        "mostro"
      ],
      [
        "z",
        "info"
      ]
    ],
    "content": "",
    "sig": "<Mostro's signature>",
    "created_at": 1731701441
  }
]
```

Below is an explanation of the meaning of some of the labels in this event, all of which can be modified by anyone running a Mostro instance.

- `mostro_version`: The version of the Mostro daemon running on the instance.
- `mostro_commit_hash`: The ID of the last commit used by the instance.
- `max_order_amount`: The maximum amount of Satoshis allowed for exchange.
- `min_order_amount`: The minimum amount of Satoshis allowed for exchange.
- `expiration_hours`: The maximum time, in hours, that an order can remain in `pending` status before it expires.
- `expiration_seconds`: The maximum time, in seconds, that an order can remain in `waiting-payment` or `waiting-buyer-invoice` status before being canceled or reverted to `pending` status.
- `fee`: The fee percentage charged by the instance. For example, "0.006" means a 0.6% fee.
- `pow`: The Proof of Work required of incoming events.
- `hold_invoice_expiration_window`: The maximum time, in seconds, for the hold invoice issued by Mostro to be paid by the seller.
- `hold_invoice_cltv_delta`: The number of blocks in which the Mostro hold invoice will expire.
- `invoice_expiration_window`: The maximum time, in seconds, for a buyer to submit an invoice to Mostro.
- `lnd_version`: The version of the LND daemon running on the instance.
- `lnd_node_pubkey`: The pubkey of the LND node running on the instance.
- `lnd_commit_hash`: The ID of the last commit used by the LND node.
- `lnd_node_alias`: The alias of the LND node.
- `lnd_chains`: The chains supported by the LND node.
- `lnd_networks`: The networks supported by the LND node.
- `lnd_uris`: The URIs of the LND node.
- `y`: The platform which is publishing its events.
- `z`: The type of event.

## Information about the Relays Where Events Are Published

The operator of a Mostro instance decides which relays the events from that instance are published to. This information can be accessed in events [kind 10002](https://github.com/nostr-protocol/nips/blob/master/65.md), which are published by the Mostro instances.

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "kind": 10002,
    "tags": [
      ["r", "wss://relay.mostro.network/"],
      ["r", "wss://nostr.bilthon.dev/"]
    ],
    "content": "",
    "sig": "<Mostro's signature>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1731680102
  }
]
```

The `r` label indicates the relays through which the Mostro instance is publishing its events.
