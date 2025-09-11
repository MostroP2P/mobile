# Peer-to-peer Chat

To communicate directly, both the buyer and the seller do not use the current `Message` scheme explained [here](https://mostro.network/protocol/overview.html), as this communication excludes the Mostro daemon. To preserve user privacy, we use a simplified version of NIP-59 that allows us to hide the metadata of both parties from outside observers. However, this variant only contains a single event inside the wrapper. The inner event includes the sender’s trade pubkey and the corresponding signature to maintain the authenticity of the sender.

## Shared Key

The messages between parties have a unique feature: instead of directing the events containing these messages to the counterparty’s trade pubkey, we direct them to a unique pubkey known only to both parties.

We use **Elliptic Curve Diffie-Hellman** (ECDH) to obtain a shared key between the two parties, which in our case serves as a master key to decrypt the wrapper’s content. Either party can voluntarily share this key with the solver in case of a dispute, so the solver can check if someone is lying.

```
Alice                            Bob
-----                            -----
Private Key: a                   Private Key: b
Public Key: A = a * G            Public Key: B = b * G
   (G is the curve’s base point)

1. Alice sends A to Bob  ----->  Bob receives A
2. Bob sends B to Alice  <-----  Alice receives B

Alice computes:                  Bob computes:
Shared Key = a * B               Shared Key = b * A
           = a * (b * G)         = b * (a * G)
           = ab * G              = ba * G
           = Same Shared Key!
```

## Example:

### 1. Creating the Inner Event

We create a kind 1 event with a message, signed by the author.

```json
{
  "id": "<Event Id>",
  "pubkey": "<Index N pubkey (trade key)>",
  "kind": 1,
  "created_at": 1691518405,
  "content": "Let’s reestablish the peer-to-peer nature of Bitcoin!",
  "tags": [],
  "sig": "<Index N (trade key) signature>"
}
```

### 2. Wrapping the Inner Event

We calculate the shared key and encrypt the JSON-encoded kind 1 inner event with the ephemeral key. The result is placed in the content field of a kind 1059 event. We add a p tag containing the shared key’s pubkey and finally sign the event using the random (ephemeral) key.

```json
{
  "content": "<Encrypted content>",
  "kind": 1059,
  "created_at": 1703021488,
  "pubkey": "<Ephemeral pubkey>",
  "id": "<Event Id>",
  "sig": "<Ephemeral key signature>",
  "tags": [["p", "<Shared Pubkey>"]]
}
```

## Encrypting Payloads

Encryption is done following [NIP-44](https://github.com/nostr-protocol/nips/blob/master/44.md) on the JSON-encoded inner event. Place the encryption payload in the `content` of the wrapper event.

## Other considerations

Clients optionally can attach a certain amount of proof-of-work to the wrapper event per [NIP-13](https://github.com/nostr-protocol/nips/blob/master/13.md) in a bid to demonstrate that the event is not spam or a denial-of-service attack to relays, this is not mandatory.

The canonical `created_at` time belongs to the inner event. The wrapper timestamp SHOULD be tweaked to thwart time-analysis attacks. Note that some relays don't serve events dated in the future, so all timestamps SHOULD be in the past.

### Code Example

#### Rust

```rust
use nostr::util::generate_shared_key;
use nostr_sdk::prelude::*;

// Alice
// Hex public key:         000053c3b4773182e7c4c1b72b272d34be01bf4414a6a25c998977c516a46a01
// Hex private key:        548f68890c49fa42f104c60352395e60ff030b0b407e955f1eed1400d6c0347a
// Npub public key:        npub1qqq98sa5wucc9e7ycxmjkfedxjlqr06yzjn2yhye39mu294ydgqsf8r490
// Nsec private key:       nsec12j8k3zgvf8ay9ugyccp4yw27vrlsxzctgplf2hc7a52qp4kqx3aq0ttwy2

// Bob
// Hex public key:         000009ae5cff9f6ba9b05159ec5ed58c187f5882ea77c81ed5dd19163272a5d7
// Hex private key:        f258e73f07386d37133718b6127f873dd7c391b8f43b331ff8254034a13d2943
// Npub public key:        npub1qqqqntjul70kh2ds29v7chk43sv87kyzafmus8k4m5v3vvnj5htshl66x6
// Nsec private key:       nsec17fvww0c88pknwyehrzmpylu88htu8ydc7sanx8lcy4qrfgfa99psdvrw0q

// Hex Shared PubKey:      27199d5878869ec3b4ae1ad5c2fed88840218a119f9ce892828b950fc96b4829
// Hex Shared private key: def6633a53d07d1e829484c4d4bdbbeed2f4b14c21743e63871c174338e39475

#[tokio::main]
async fn main() -> Result<()> {
    // Alice
    let alice_keys =
        Keys::parse("548f68890c49fa42f104c60352395e60ff030b0b407e955f1eed1400d6c0347a")?;
    // Bob
    let bob_keys = Keys::parse("f258e73f07386d37133718b6127f873dd7c391b8f43b331ff8254034a13d2943")?;
    // Show Alice bech32 public key
    let alice_pubkey = alice_keys.public_key();
    let alice_secret = alice_keys.secret_key();
    println!("Alice PubKey: {}", alice_pubkey);

    // Generate shared key for Alice
    let shared_key = generate_shared_key(alice_secret, &bob_keys.public_key())?;
    let shared_secret_key = SecretKey::from_slice(&shared_key)?;
    let shared_keys = Keys::new(shared_secret_key);
    println!("Shared PubKey: {}", shared_keys.public_key());
    println!(
        "Shared private key: {}",
        shared_keys.secret_key().to_secret_hex()
    );
    // Generate shared key for Bob
    let bob_shared_key = generate_shared_key(bob_keys.secret_key(), &alice_keys.public_key())?;
    // Check if both shared keys are the same, shared keys are not the same it panic
    assert_eq!(shared_key, bob_shared_key);
    // Show Bob bech32 public key
    let bob_pubkey = bob_keys.public_key();
    // let bob_secret = bob_keys.secret_key();
    println!("Bob PubKey: {}", bob_pubkey);

    let message = "Let’s reestablish the peer-to-peer nature of Bitcoin!";
    // We encrypt the event to the shared key and only can be decrypted by the shared key
    // and sign the inside event with the sender key, in this case Alice
    // We do this to ensure that the message is from Alice and only Bob can read it
    // But both parties can `shared` the shared key to anyone to decrypt the message
    // This is useful for p2p like Mostro where in case of a dispute the message can be decrypted
    // by a third party to know if someone is lying
    let wrapped_event = mostro_wrap(&alice_keys, shared_keys.public_key(), message, vec![]).await?;
    println!("Outer event: {:#?}", wrapped_event);

    // We decrypt the event with the shared key
    let unwrapped_event = mostro_unwrap(&shared_keys, wrapped_event).await.unwrap();
    println!("Inner event: {:#?}", unwrapped_event);

    Ok(())
}

/// Wraps a message in a non standard and simplified NIP-59 event.
/// The inner event is signed with the sender's key and encrypted to the receiver's
/// public key using an ephemeral key.
///
/// # Arguments
/// - `sender`: The sender's keys for signing the inner event.
/// - `receiver`: The receiver's public key for encryption.
/// - `message`: The message to wrap.
/// - `extra_tags`: Additional tags to include in the wrapper event.
///
/// # Returns
/// A signed `Event` representing the NON STANDARD gift wrap.
pub async fn mostro_wrap(
    sender: &Keys,
    receiver: PublicKey,
    message: &str,
    extra_tags: Vec<Tag>,
) -> Result<Event, Box<dyn std::error::Error>> {
    let inner_event = EventBuilder::text_note(message)
        .build(sender.public_key())
        .sign(sender)
        .await?;
    let keys: Keys = Keys::generate();
    let encrypted_content: String = nip44::encrypt(
        keys.secret_key(),
        &receiver,
        inner_event.as_json(),
        nip44::Version::V2,
    )
    .unwrap();

    // Build tags for the wrapper event
    let mut tags = vec![Tag::public_key(receiver)];
    tags.extend(extra_tags);

    // Create and sign the gift wrap event
    let wrapped_event = EventBuilder::new(Kind::GiftWrap, encrypted_content)
        .tags(tags)
        .custom_created_at(Timestamp::tweaked(nip59::RANGE_RANDOM_TIMESTAMP_TWEAK))
        .sign_with_keys(&keys)?;

    Ok(wrapped_event)
}

/// Unwraps an non standard NIP-59 event and retrieves the inner event.
/// The receiver uses their private key to decrypt the content.
///
/// # Arguments
/// - `receiver`: The receiver's keys for decryption.
/// - `event`: The wrapped event to unwrap.
///
/// # Returns
/// The decrypted inner `Event`.
pub async fn mostro_unwrap(
    receiver: &Keys,
    event: Event,
) -> Result<Event, Box<dyn std::error::Error>> {
    let decrypted_content = nip44::decrypt(receiver.secret_key(), &event.pubkey, &event.content)?;
    let inner_event = Event::from_json(&decrypted_content)?;

    // Verify the event before returning
    inner_event.verify()?;

    Ok(inner_event)
}
```

More details about this implementation can be found in this [repository](https://github.com/MostroP2P/mostro-chat).
