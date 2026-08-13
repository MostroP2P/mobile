import 'dart:convert';
import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';

/// Domain-separated key pair for the Mostro chat envelope (kind 14).
///
/// Derived from the 32-byte ECDH shared secret between the two chat parties
/// (trade key <-> admin key for dispute chat, trade key <-> trade key for
/// peer chat) via HKDF-SHA256:
///
/// - [conv] (`K_conv`): NIP-44 encryption key; its pubkey is the outer `p` tag
/// - [sign] (`K_sign`): signs the outer kind 14 event; its pubkey is the
///   relay `authors` subscription filter
///
/// Spec: https://mostro.network/protocol/chat.html#key-derivation
class ChatKeys {
  /// HKDF info for `K_conv`. Changing this value changes the wire format.
  static const convInfo = 'mostro:chat:conv:v1';

  /// HKDF info for `K_sign`. Changing this value changes the wire format.
  static const signInfo = 'mostro:chat:sign:v1';

  final NostrKeyPairs conv;
  final NostrKeyPairs sign;

  const ChatKeys({required this.conv, required this.sign});

  /// Derive `(K_conv, K_sign)` from an ECDH shared key pair such as
  /// `session.adminSharedKey`, whose private key is the hex-encoded
  /// 32-byte ECDH output.
  factory ChatKeys.fromSharedKey(NostrKeyPairs sharedKey) {
    return ChatKeys.fromSharedSecret(
      Uint8List.fromList(hex.decode(sharedKey.private)),
    );
  }

  /// Derive `(K_conv, K_sign)` from the raw 32-byte ECDH shared secret.
  factory ChatKeys.fromSharedSecret(Uint8List sharedSecret) {
    if (sharedSecret.length != 32) {
      throw ArgumentError(
        'Chat shared secret must be 32 bytes, got ${sharedSecret.length}',
      );
    }

    // HKDF-extract with an absent salt (RFC 5869: zero-filled, hash length)
    final prk = Hmac(sha256, List.filled(32, 0)).convert(sharedSecret).bytes;

    return ChatKeys(
      conv: _deriveKey(prk, convInfo),
      sign: _deriveKey(prk, signInfo),
    );
  }

  /// HKDF-expand a single 32-byte block and interpret it as a secp256k1
  /// secret key. On the negligible chance the output is not a valid key,
  /// retry with a counter byte appended to the info (spec requirement).
  static NostrKeyPairs _deriveKey(List<int> prk, String info) {
    final base = utf8.encode(info);
    for (var counter = 0; counter <= 255; counter++) {
      final labelled = counter == 0 ? base : [...base, counter];
      final okm = Hmac(sha256, prk).convert([...labelled, 0x01]).bytes;
      try {
        return NostrKeyPairs(private: hex.encode(okm));
      } catch (_) {
        continue;
      }
    }
    throw StateError('HKDF failed to produce a valid secret key for $info');
  }
}
