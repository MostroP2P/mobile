import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:math';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:elliptic/elliptic.dart';
import 'package:nip44/nip44.dart';

class NostrUtils {
  static final Nostr _instance = Nostr.instance;

  // Key generation
  static NostrKeyPairs generateKeyPair() {
    try {
      final privateKey = generatePrivateKey();
      if (!isValidPrivateKey(privateKey)) {
        throw Exception('Generated invalid private key');
      }
      return NostrKeyPairs(private: privateKey);
    } catch (e) {
      throw Exception('Failed to generate key pair: $e');
    }
  }

  static NostrKeyPairs generateKeyPairFromPrivateKey(String privateKey) {
    return _instance.services.keys.generateKeyPairFromExistingPrivateKey(
      privateKey,
    );
  }

  static String generatePrivateKey() {
    try {
      return getS256().generatePrivateKey().toHex();
    } catch (e) {
      throw Exception('Failed to generate private key: $e');
    }
  }

  // Key encoding and decoding
  static String encodePrivateKeyToNsec(String privateKey) {
    return _instance.services.bech32.encodePrivateKeyToNsec(privateKey);
  }

  static String decodeNsecKeyToPrivateKey(String nsec) {
    return _instance.services.bech32.decodeNsecKeyToPrivateKey(nsec);
  }

  static String encodePublicKeyToNpub(String publicKey) {
    return _instance.services.bech32.encodePublicKeyToNpub(publicKey);
  }

  static String decodeNpubKeyToPublicKey(String npub) {
    return _instance.services.bech32.decodeNpubKeyToPublicKey(npub);
  }

  static String nsecToHex(String nsec) {
    if (nsec.startsWith('nsec')) {
      return decodeNsecKeyToPrivateKey(nsec);
    }
    return nsec; // If already hex, return as is
  }

  // Key operations
  static String derivePublicKey(String privateKey) {
    return _instance.services.keys.derivePublicKey(privateKey: privateKey);
  }

  static bool isValidPrivateKey(String privateKey) {
    return _instance.services.keys.isValidPrivateKey(privateKey);
  }

  // Signing and verification
  static String signMessage(String message, String privateKey) {
    return _instance.services.keys.sign(
      privateKey: privateKey,
      message: message,
    );
  }

  static bool verifySignature(
    String signature,
    String message,
    String publicKey,
  ) {
    return _instance.services.keys.verify(
      publicKey: publicKey,
      message: message,
      signature: signature,
    );
  }

  // Event creation
  static NostrEvent createEvent({
    required int kind,
    required String content,
    required String privateKey,
    List<List<String>> tags = const [],
    DateTime? createdAt,
  }) {
    final keyPair = generateKeyPairFromPrivateKey(privateKey);
    return NostrEvent.fromPartialData(
      kind: kind,
      content: content,
      keyPairs: keyPair,
      tags: tags,
      createdAt: createdAt,
    );
  }

  // General utilities
  static String decodeBech32(String bech32String) {
    final result = _instance.services.bech32.decodeBech32(bech32String);
    return result[0]; // Return data part (index 0)
  }

  static String encodeBech32(String hrp, String data) {
    return _instance.services.bech32.encodeBech32(hrp, data);
  }

  /// Validates if a string is a valid mostro: URL
  /// Format: mostro:order-id&relays=wss://relay1,wss://relay2
  static bool isValidMostroUrl(String url) {
    if (!url.startsWith('mostro:')) return false;

    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'mostro') return false;

      // Check if we have an order ID (path)
      final orderId = uri.path;
      if (orderId.isEmpty) return false;

      // Check if relays parameter exists
      final relaysParam = uri.queryParameters['relays'];
      if (relaysParam == null || relaysParam.isEmpty) return false;

      // Validate relay URLs
      final relays = relaysParam.split(',');
      for (final relay in relays) {
        final trimmedRelay = relay.trim();
        if (!trimmedRelay.startsWith('wss://') &&
            !trimmedRelay.startsWith('ws://')) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parses a mostro: URL and returns order information
  /// Format: mostro:order-id&relays=wss://relay1,wss://relay2
  /// Returns a map with 'orderId' and 'relays' keys
  static Map<String, dynamic>? parseMostroUrl(String url) {
    if (!isValidMostroUrl(url)) return null;

    try {
      final uri = Uri.parse(url);

      final orderId = uri.path;
      final relaysParam = uri.queryParameters['relays'];

      if (orderId.isEmpty || relaysParam == null) return null;

      final relays = relaysParam
          .split(',')
          .map((relay) => relay.trim())
          .where((relay) => relay.isNotEmpty)
          .toList();

      return {'orderId': orderId, 'relays': relays};
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pubKeyFromIdentifierNip05(
    String internetIdentifier,
  ) async {
    return await _instance.services.utils.pubKeyFromIdentifierNip05(
      internetIdentifier: internetIdentifier,
    );
  }

  // Method to generate event ID in Nostr
  static String generateId(Map<String, dynamic> eventData) {
    final jsonString = jsonEncode([
      0, // Event version
      eventData['pubkey'], // Public key
      eventData['created_at'], // Timestamp
      eventData['kind'], // Event type
      eventData['tags'], // Event tags
      eventData['content'], // Event content
    ]);

    // Calculate SHA-256 hash to generate ID
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);

    return digest.toString(); // Return ID as hex string
  }

  /// Generates a timestamp between now and 48 hours ago to enhance privacy
  /// by decorrelating event timing from creation time.
  /// @throws if system clock is ahead of network time
  static DateTime randomNow() {
    final now = DateTime.now();
    // Validate system time isn't ahead
    final networkTime = DateTime.now().toUtc();
    if (now.isAfter(networkTime.add(Duration(minutes: 5)))) {
      throw Exception('System clock is ahead of network time');
    }
    final randomSeconds = Random().nextInt(2 * 24 * 60 * 60);
    return now.subtract(Duration(seconds: randomSeconds));
  }

  static Future<String> createRumor(
    NostrKeyPairs senderKeyPair,
    String wrapperKey,
    String recipientPubKey,
    String content,
  ) async {
    final rumorEvent = NostrEvent.fromPartialData(
      kind: 1,
      keyPairs: senderKeyPair,
      content: content,
      createdAt: DateTime.now(),
      tags: [
        ["p", recipientPubKey],
      ],
    );

    try {
      return await encryptNIP44(
        jsonEncode(rumorEvent.toMap()),
        wrapperKey,
        recipientPubKey,
      );
    } catch (e) {
      throw Exception('Failed to encrypt content: $e');
    }
  }

  static Future<String> createSeal(
    NostrKeyPairs senderKeyPair,
    String wrapperKey,
    String recipientPubKey,
    String encryptedContent,
  ) async {
    final sealEvent = NostrEvent.fromPartialData(
      kind: 13,
      keyPairs: senderKeyPair,
      content: encryptedContent,
      createdAt: randomNow(),
    );

    return await encryptNIP44(
      jsonEncode(sealEvent.toMap()),
      wrapperKey,
      recipientPubKey,
    );
  }

  /// Creates a NIP-59 wrapper event with optional NIP-13 proof-of-work.
  ///
  /// When [difficulty] is greater than 0, the wrapper event is mined to
  /// produce an event id with the required number of leading zero bits,
  /// as specified in NIP-13. This is required by Mostro instances that
  /// set a `pow` value in their kind 38385 info event.
  ///
  /// Mining runs in a separate isolate to avoid blocking the UI thread.
  static Future<NostrEvent> createWrap(
    NostrKeyPairs wrapperKeyPair,
    String sealedContent,
    String recipientPubKey, {
    int difficulty = 0,
  }) async {
    final wrapEvent = NostrEvent.fromPartialData(
      kind: 1059,
      content: sealedContent,
      keyPairs: wrapperKeyPair,
      tags: [
        ["p", recipientPubKey],
      ],
      createdAt: randomNow(),
    );

    if (difficulty > 0) {
      return mineProofOfWork(wrapEvent, difficulty, wrapperKeyPair);
    }

    return wrapEvent;
  }

  static NostrKeyPairs computeSharedKey(String privateKey, String publicKey) {
    final sharedKey = Nip44.computeSharedSecret(privateKey, publicKey);
    final nkey = hex.encode(sharedKey);
    return NostrKeyPairs(private: nkey);
  }

  /// Convert a NostrKeyPairs shared key to raw bytes for encryption operations.
  /// Used by both P2P chat and dispute chat for multimedia encryption.
  static Uint8List sharedKeyToBytes(NostrKeyPairs sharedKey) {
    final hexKey = sharedKey.private;
    if (hexKey.length != 64) {
      throw Exception(
        'Invalid shared key length: expected 64 hex chars, got ${hexKey.length}',
      );
    }
    final bytes = Uint8List(32);
    for (int i = 0; i < 32; i++) {
      bytes[i] = int.parse(hexKey.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return bytes;
  }

  /// Creates a NIP-59 encrypted event with the following structure:
  /// 1. Inner event (kind 1): Original content
  /// 2. Seal event (kind 13): Encrypted inner event
  /// 3. Wrapper event (kind 1059): Final encrypted package
  static Future<NostrEvent> createNIP59Event(
    String content,
    String recipientPubKey,
    String senderPrivateKey, {
    int difficulty = 0,
  }) async {
    // Validate inputs
    if (content.isEmpty) throw ArgumentError('Content cannot be empty');
    if (recipientPubKey.length != 64) {
      throw ArgumentError('Invalid recipient public key');
    }
    if (!isValidPrivateKey(senderPrivateKey)) {
      throw ArgumentError('Invalid sender private key');
    }

    final senderKeyPair = generateKeyPairFromPrivateKey(senderPrivateKey);

    String encryptedContent = await createRumor(
      senderKeyPair,
      senderKeyPair.private,
      recipientPubKey,
      content,
    );

    final wrapperKeyPair = generateKeyPair();

    String sealedContent = await createSeal(
      senderKeyPair,
      wrapperKeyPair.private,
      recipientPubKey,
      encryptedContent,
    );

    final wrapEvent = await createWrap(
      wrapperKeyPair,
      sealedContent,
      recipientPubKey,
      difficulty: difficulty,
    );

    return wrapEvent;
  }

  static Future<NostrEvent> decryptNIP59Event(
    NostrEvent event,
    String privateKey,
  ) async {
    if (event.kind != 1059) {
      throw ArgumentError('Wrong kind: ${event.kind}');
    }
    // Validate inputs
    if (event.content == null || event.content!.isEmpty) {
      throw ArgumentError('Event content is empty');
    }
    if (!isValidPrivateKey(privateKey)) {
      throw ArgumentError('Invalid private key');
    }

    try {
      final decryptedContent = await decryptNIP44(
        event.content!,
        privateKey,
        event.pubkey,
      );

      final rumorEvent = NostrEvent.deserialized(
        '["EVENT", "", $decryptedContent]',
      );

      final finalDecryptedContent = await decryptNIP44(
        rumorEvent.content!,
        privateKey,
        rumorEvent.pubkey,
      );

      final wrap = jsonDecode(finalDecryptedContent) as Map<String, dynamic>;

      // Validate decrypted event structure
      _validateEventStructure(wrap);

      return NostrEvent(
        id: wrap['id'] as String,
        kind: wrap['kind'] as int,
        content: wrap['content'] as String,
        sig: "",
        pubkey: wrap['pubkey'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (wrap['created_at'] as int) * 1000,
        ),
        tags: List<List<String>>.from(
          (wrap['tags'] as List)
              .map(
                (nestedElem) => (nestedElem as List)
                    .map((nestedElemContent) => nestedElemContent.toString())
                    .toList(),
              )
              .toList(),
        ),
        subscriptionId: '',
      );
    } catch (e) {
      throw Exception('Failed to decrypt NIP-59 event: $e');
    }
  }

  /// Validates the structure of a decrypted event
  static void _validateEventStructure(Map<String, dynamic> event) {
    final requiredFields = [
      'id',
      'kind',
      'content',
      'pubkey',
      'created_at',
      'tags',
    ];
    for (final field in requiredFields) {
      if (!event.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
    }
  }

  /// Checks if a decoded Mostro payload item is a DM (dispute/admin chat) message.
  /// DM messages use the format: {"dm": {"action": "send-dm", ...}}
  /// Validates shape strictly to avoid false positives from other payloads.
  static bool isDmPayload(dynamic item) {
    if (item is! Map) return false;
    final dm = item['dm'];
    return dm is Map && dm['action'] == 'send-dm';
  }

  static Future<String> encryptNIP44(
    String content,
    String privkey,
    String pubkey,
  ) async {
    try {
      return await Nip44.encryptMessage(content, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Encryption failed: $e');
    }
  }

  static Future<String> decryptNIP44(
    String encryptedContent,
    String privkey,
    String pubkey,
  ) async {
    try {
      return await Nip44.decryptMessage(encryptedContent, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Decryption failed: $e');
    }
  }

  /// Counts the number of leading zero bits in a hex string (NIP-13).
  static int _countLeadingZeroBits(String hex) {
    int count = 0;
    for (int i = 0; i < hex.length; i++) {
      final nibble = int.parse(hex[i], radix: 16);
      if (nibble == 0) {
        count += 4;
      } else {
        // Count leading zeros in this nibble
        if (nibble < 2) {
          count += 3;
        } else if (nibble < 4) {
          count += 2;
        } else if (nibble < 8) {
          count += 1;
        }
        break;
      }
    }
    return count;
  }

  /// Mines a NIP-13 proof-of-work nonce for the given event parameters.
  ///
  /// This is designed to run in a separate isolate via [compute] to avoid
  /// blocking the UI thread.
  ///
  /// Returns a map with 'nonce' (the winning nonce) and 'id' (the mined event id).
  static Map<String, String> _mineNonce(Map<String, dynamic> params) {
    final int kind = params['kind'];
    final String contentStr = params['content'];
    final int createdAtSeconds = params['createdAt'];
    final String pubkey = params['pubkey'];
    final List<List<String>> baseTags = (params['tags'] as List)
        .map((t) => (t as List).map((e) => e.toString()).toList())
        .toList();
    final int difficulty = params['difficulty'];

    // Add nonce tag placeholder
    final nonceTagIndex = baseTags.length;
    baseTags.add(['nonce', '0', difficulty.toString()]);

    for (int nonce = 0; nonce < 0x7FFFFFFF; nonce++) {
      baseTags[nonceTagIndex] = [
        'nonce',
        nonce.toString(),
        difficulty.toString(),
      ];

      final data = [0, pubkey, createdAtSeconds, kind, baseTags, contentStr];
      final serialized = jsonEncode(data);
      final bytes = utf8.encode(serialized);
      final digest = sha256.convert(bytes);
      final id = hex.encode(digest.bytes);

      if (_countLeadingZeroBits(id) >= difficulty) {
        return {'nonce': nonce.toString(), 'id': id};
      }
    }

    throw Exception('Failed to mine PoW after max iterations');
  }

  /// Mines NIP-13 proof-of-work for a NostrEvent.
  ///
  /// Creates a new event with a `["nonce", "<value>", "<difficulty>"]` tag
  /// that produces an event id with the required number of leading zero bits.
  ///
  /// Maximum supported PoW difficulty to prevent abuse from misconfigured
  /// or hostile Mostro nodes that could trigger unbounded CPU work.
  static const int maxPowDifficulty = 24;

  /// The mining runs in a separate isolate to avoid blocking the UI.
  /// Difficulty of 0 returns the event unchanged.
  /// Throws [ArgumentError] if difficulty exceeds [maxPowDifficulty].
  static Future<NostrEvent> mineProofOfWork(
    NostrEvent event,
    int difficulty,
    NostrKeyPairs keyPairs,
  ) async {
    if (difficulty <= 0) return event;

    if (difficulty > maxPowDifficulty) {
      throw ArgumentError.value(
        difficulty,
        'difficulty',
        'PoW difficulty exceeds supported maximum $maxPowDifficulty',
      );
    }

    final createdAt = event.createdAt ?? DateTime.now();
    final createdAtSeconds = createdAt.millisecondsSinceEpoch ~/ 1000;

    // Prepare base tags (without nonce — it will be added in the mining loop)
    final baseTags = (event.tags ?? [])
        .where((tag) => tag.isNotEmpty && tag[0] != 'nonce')
        .map((tag) => tag.toList())
        .toList();

    final result = await compute(_mineNonce, {
      'kind': event.kind,
      'content': event.content ?? '',
      'createdAt': createdAtSeconds,
      'pubkey': event.pubkey,
      'tags': baseTags.map((t) => t.toList()).toList(),
      'difficulty': difficulty,
    });

    final minedNonce = result['nonce']!;
    final minedId = result['id']!;

    // Reconstruct tags with the winning nonce
    final finalTags = [
      ...baseTags,
      ['nonce', minedNonce, difficulty.toString()],
    ];

    // Sign the mined event id
    final sig = keyPairs.sign(minedId);

    return NostrEvent(
      id: minedId,
      kind: event.kind!,
      content: event.content ?? '',
      sig: sig,
      pubkey: event.pubkey,
      createdAt: createdAt,
      tags: finalTags,
    );
  }
}
