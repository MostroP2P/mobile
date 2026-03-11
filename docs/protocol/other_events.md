# Other events published by Mostro

Each Mostro instance publishes several types of events to Nostr relays. These include identity metadata, instance status, relay lists, and development fee records. Below, we provide details on each of these events.

## Node Identity (NIP-01 Kind 0)

Each Mostro instance publishes a [NIP-01](https://github.com/nostr-protocol/nips/blob/master/01.md) kind 0 metadata event on startup so that Nostr clients can display the node's profile information. This is the standard Nostr profile mechanism — every relay-aware client already knows how to fetch and display kind 0 metadata.

The event is a **replaceable event**, meaning relays keep only the latest version. It is re-published on every restart, ensuring the profile stays fresh.

The `content` field contains a stringified JSON object with the following optional fields:

```json
{
  "name": "Mostro P2P",
  "about": "A peer-to-peer Bitcoin trading daemon over the Lightning Network",
  "picture": "https://example.com/mostro-avatar.png",
  "website": "https://mostro.network"
}
```

The full event looks like this:

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "pubkey": "<Mostro's pubkey>",
    "kind": 0,
    "tags": [],
    "content": "{\"name\":\"Mostro P2P\",\"about\":\"A peer-to-peer Bitcoin trading daemon over the Lightning Network\",\"picture\":\"https://example.com/mostro-avatar.png\",\"website\":\"https://mostro.network\"}",
    "sig": "<Mostro's signature>",
    "created_at": 1731701441
  }
]
```

### Fields

- `name`: Human-readable name for the Mostro instance (e.g., "LatAm Mostro", "Bitcoin Munich Exchange").
- `about`: Short description of the instance and the community it serves.
- `picture`: URL to an avatar image. Recommended: square, max 128×128 pixels, PNG or JPEG.
- `website`: Operator's website URL.

All fields are optional. If no metadata fields are configured, no kind 0 event is published. These fields are configured in the `[mostro]` section of `settings.toml`:

```toml
[mostro]
name = "Mostro P2P"
about = "A peer-to-peer Bitcoin trading daemon over the Lightning Network"
picture = "https://example.com/mostro-avatar.png"
website = "https://mostro.network"
```

This allows clients like Mostro Mobile to display meaningful information about each Mostro instance — its name, description, avatar, and website — so users know which node they are trading on.

## Mostro Instance Status

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
    "kind": 38385,
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
        "fiat_currencies_accepted",
        "USD,EUR,ARS,CUP,VES"
      ],
      [
        "max_orders_per_response",
        "10"
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
- `fiat_currencies_accepted`: Fiat currencies accepted by the Mostro. If no currency is specified, all are accepted.
- `max_orders_per_response`: Maximum complete orders data per response in orders action.
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
      ["r", "wss://nos.lol/"]
    ],
    "content": "",
    "sig": "<Mostro's signature>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1731680102
  }
]
```

The `r` label indicates the relays through which the Mostro instance is publishing its events.

# Development Fee

The development fee mechanism provides sustainable funding for Mostro development by automatically sending a configurable percentage of the Mostro fee to a lightning address on each successful order, this a regular event with kind 8383 which is expected to be stored by relays.

```json
[
  "EVENT",
  "RAND",
  {
    "id": "<Event id>",
    "tags": [
      [
        "order-id",
        "<Order id>"
      ],
      [
        "amount",
        "8" // sats amount
      ],
      [
        "hash",
        "ca2f47b7c2169b8c42ef135e8ee32706e1fd3722b65e5a16f21ce675d2affb6b"
      ],
      [
        "destination",
        "dev@mostro.network"
      ],
      [
        "network",
        "mainnet"
      ],
      [
        "y",
        "mostro"
      ],
      [
        "z",
        "dev-fee-payment"
      ]
    ],
    "content": "",
    "sig": "<Mostro's signature>",
    "pubkey": "<Mostro's pubkey>",
    "created_at": 1768256716,
    "kind": 8383
  }
]
```