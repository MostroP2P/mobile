# Dispute Chat

The dispute chat uses the same shared key encryption scheme as the [Peer-to-peer Chat](./chat.md). Instead of computing a shared key between buyer and seller, each party computes an independent shared key with the admin who took the dispute.

## Establishing the shared key

When an admin takes a dispute, Mostro sends an `admin-took-dispute` message to each party (buyer and seller) containing the admin's pubkey:

```json
[
  {
    "order": {
      "version": 1,
      "id": "<Order Id>",
      "action": "admin-took-dispute",
      "payload": {
        "peer": {
          "pubkey": "<Admin's pubkey>"
        }
      }
    }
  },
  null
]
```

Upon receiving this message, the client computes the shared key using ECDH:

```
Shared Key = ECDH(tradeKey.private, adminPubkey)
```

The admin computes the same shared key from their side:

```
Shared Key = ECDH(adminPrivateKey, tradeKey.public)
```

Each party (buyer and seller) has its own independent shared key with the admin. A session can have both a peer shared key (for the P2P chat) and an admin shared key (for the dispute chat) simultaneously.

## Sending and receiving messages

Messages are wrapped and unwrapped using the same simplified NIP-59 scheme described in [Peer-to-peer Chat](./chat.md#example). The inner event is a kind 1 event signed by the sender's key, encrypted with NIP-44 and placed inside a kind 1059 Gift Wrap event.

The `p` tag in the wrapper event points to the **admin shared key's pubkey**, not the trade key:

```json
{
  "content": "<Encrypted content>",
  "kind": 1059,
  "created_at": 1703021488,
  "pubkey": "<Ephemeral pubkey>",
  "id": "<Event Id>",
  "sig": "<Ephemeral key signature>",
  "tags": [["p", "<Admin Shared Pubkey>"]]
}
```

## Subscribing to messages

Clients subscribe to kind 1059 events filtered by the admin shared key's pubkey:

```json
{
  "kinds": [1059],
  "#p": ["<Admin Shared Pubkey>"]
}
```

Clients should discard any messages received from pubkeys other than the Mostro node or the dispute solver.
