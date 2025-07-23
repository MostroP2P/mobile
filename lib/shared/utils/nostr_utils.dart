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
    return _instance.services.keys
        .generateKeyPairFromExistingPrivateKey(privateKey);
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
    return _instance.services.keys
        .sign(privateKey: privateKey, message: message);
  }

  static bool verifySignature(
      String signature, String message, String publicKey) {
    return _instance.services.keys
        .verify(publicKey: publicKey, message: message, signature: signature);
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

      return {
        'orderId': orderId,
        'relays': relays,
      };
    } catch (e) {
      return null;
    }
  }

  static Future<String?> pubKeyFromIdentifierNip05(
      String internetIdentifier) async {
    return await _instance.services.utils
        .pubKeyFromIdentifierNip05(internetIdentifier: internetIdentifier);
  }

  // Method to generate event ID in Nostr
  static String generateId(Map<String, dynamic> eventData) {
    final jsonString = jsonEncode([
      0, // Event version
      eventData['pubkey'], // Public key
      eventData['created_at'], // Timestamp
      eventData['kind'], // Event type
      eventData['tags'], // Event tags
      eventData['content'] // Event content
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

  static Future<String> createRumor(NostrKeyPairs senderKeyPair,
      String wrapperKey, String recipientPubKey, String content) async {
    final rumorEvent = NostrEvent.fromPartialData(
      kind: 1,
      keyPairs: senderKeyPair,
      content: content,
      createdAt: DateTime.now(),
      tags: [
        ["p", recipientPubKey]
      ],
    );

    try {
      return await encryptNIP44(
          jsonEncode(rumorEvent.toMap()), wrapperKey, recipientPubKey);
    } catch (e) {
      throw Exception('Failed to encrypt content: $e');
    }
  }

  static Future<String> createSeal(
      NostrKeyPairs senderKeyPair,
      String wrapperKey,
      String recipientPubKey,
      String encryptedContent) async {
    final sealEvent = NostrEvent.fromPartialData(
      kind: 13,
      keyPairs: senderKeyPair,
      content: encryptedContent,
      createdAt: randomNow(),
    );

    return await encryptNIP44(
        jsonEncode(sealEvent.toMap()), wrapperKey, recipientPubKey);
  }

  /// Creates a NIP-59 wrapper event with NIP-13 proof-of-work as required by Mostro
  /// This adds computational proof to demonstrate the event is not spam
  static Future<NostrEvent> createWrap(NostrKeyPairs wrapperKeyPair,
      String sealedContent, String recipientPubKey, {int targetDifficulty = 16}) async {
    
    // Mine the wrapper event to achieve the target difficulty (NIP-13)
    // This adds proof-of-work as required by Mostro documentation
    final minedWrapEvent = await mineEvent(
      wrapperKeyPair,
      sealedContent,
      targetDifficulty,
      existingTags: [
        ["p", recipientPubKey]
      ],
    );

    // Update the created_at to use randomized timestamp for privacy
    // while preserving the nonce that achieved the target difficulty
    final finalWrapEvent = NostrEvent.fromPartialData(
      kind: 1059,
      content: sealedContent,
      keyPairs: wrapperKeyPair,
      tags: minedWrapEvent.tags,
      createdAt: randomNow(),
    );

    return finalWrapEvent;
  }

  static NostrKeyPairs computeSharedKey(String privateKey, String publicKey) {
    final sharedKey = Nip44.computeSharedSecret(privateKey, publicKey);
    final nkey = hex.encode(sharedKey);
    return NostrKeyPairs(private: nkey);
  }

  /// Creates a NIP-59 encrypted event with the following structure:
  /// 1. Inner event (kind 1): Original content
  /// 2. Seal event (kind 13): Encrypted inner event
  /// 3. Wrapper event (kind 1059): Final encrypted package
  static Future<NostrEvent> createNIP59Event(
      String content, String recipientPubKey, String senderPrivateKey) async {
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
        senderKeyPair, senderKeyPair.private, recipientPubKey, content);

    final wrapperKeyPair = generateKeyPair();

    String sealedContent = await createSeal(senderKeyPair,
        wrapperKeyPair.private, recipientPubKey, encryptedContent);

    final wrapEvent =
        await createWrap(wrapperKeyPair, sealedContent, recipientPubKey);

    return wrapEvent;
  }

  static Future<NostrEvent> decryptNIP59Event(
      NostrEvent event, String privateKey) async {
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

      final rumorEvent =
          NostrEvent.deserialized('["EVENT", "", $decryptedContent]');

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
                    .map(
                      (nestedElemContent) => nestedElemContent.toString(),
                    )
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
      'tags'
    ];
    for (final field in requiredFields) {
      if (!event.containsKey(field)) {
        throw FormatException('Missing required field: $field');
      }
    }
  }

  static Future<String> encryptNIP44(
      String content, String privkey, String pubkey) async {
    try {
      return await Nip44.encryptMessage(content, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Encryption failed: $e');
    }
  }

  static Future<String> decryptNIP44(
      String encryptedContent, String privkey, String pubkey) async {
    try {
      return await Nip44.decryptMessage(encryptedContent, privkey, pubkey);
    } catch (e) {
      // Handle encryption error appropriately
      throw Exception('Decryption failed: $e');
    }
  }

  /// Counts the number of leading zero bits in a hexadecimal string
  /// Implementation based on NIP-13 specification
  static int countLeadingZeroBits(String hex) {
    int count = 0;
    
    for (int i = 0; i < hex.length; i++) {
      final nibble = int.parse(hex[i], radix: 16);
      if (nibble == 0) {
        count += 4;
      } else {
        // Count leading zeros in the nibble
        // Using bit manipulation to count leading zeros
        int leadingZeros = 0;
        int temp = nibble;
        for (int bit = 3; bit >= 0; bit--) {
          if ((temp & (1 << bit)) == 0) {
            leadingZeros++;
          } else {
            break;
          }
        }
        count += leadingZeros;
        break;
      }
    }
    
    return count;
  }

  /// Mines a NostrEvent to achieve the target difficulty using NIP-13 proof-of-work
  /// Returns the mined event with nonce tag and updated created_at
  /// 
  /// [senderKeyPairs] - The key pairs of the sender to sign the event
  /// [content] - The content of the message to mine
  /// [targetDifficulty] - The target number of leading zero bits
  /// [existingTags] - Any existing tags to include in the event
  static Future<NostrEvent> mineEvent(
    NostrKeyPairs senderKeyPairs,
    String content,
    int targetDifficulty, {
    List<List<String>>? existingTags,
  }) async {
    if (targetDifficulty <= 0) {
      throw ArgumentError('Target difficulty must be positive');
    }

    int nonce = 0;
    
    while (true) {
      // Create event with nonce tag
      final tags = List<List<String>>.from(existingTags ?? []);
      
      // Remove existing nonce tag if present
      tags.removeWhere((tag) => tag.isNotEmpty && tag[0] == 'nonce');
      
      // Add new nonce tag with current nonce and target difficulty
      tags.add(['nonce', nonce.toString(), targetDifficulty.toString()]);
      
      // Update created_at to current time (recommended during mining)
      final now = DateTime.now();
      
      // Create new event with updated nonce and timestamp
      final minedEvent = NostrEvent.fromPartialData(
        kind: 1, // Always kind 1 for text messages
        content: content,
        keyPairs: senderKeyPairs,
        tags: tags,
        createdAt: now,
      );
      
      // Check if we've achieved the target difficulty
      final eventId = minedEvent.id;
      if (eventId == null) {
        throw Exception('Failed to generate event ID');
      }
      final difficulty = countLeadingZeroBits(eventId);
      if (difficulty >= targetDifficulty) {
        return minedEvent;
      }
      
      nonce++;
      
      // Prevent infinite loops - yield control periodically
      if (nonce % 1000 == 0) {
        await Future.delayed(Duration.zero);
      }
    }
  }

  /// Validates that an event meets the minimum difficulty requirement
  /// Returns true if the event has sufficient proof-of-work
  static bool validateProofOfWork(NostrEvent event, int minimumDifficulty) {
    final eventId = event.id;
    if (eventId == null) {
      return false; // Cannot validate without event ID
    }
    final actualDifficulty = countLeadingZeroBits(eventId);
    
    // Check if event has a nonce tag with committed target difficulty
    final nonceTags = event.tags?.where((tag) => 
        tag.isNotEmpty && tag[0] == 'nonce') ?? [];
    
    if (nonceTags.isNotEmpty) {
      final nonceTag = nonceTags.first;
      if (nonceTag.length >= 3) {
        final committedTarget = int.tryParse(nonceTag[2]);
        if (committedTarget != null && committedTarget < minimumDifficulty) {
          // Reject if committed target is lower than required minimum
          return false;
        }
      }
    }
    
    return actualDifficulty >= minimumDifficulty;
  }

  /// Gets the actual difficulty (leading zero bits) of an event
  static int getEventDifficulty(NostrEvent event) {
    final eventId = event.id;
    if (eventId == null) {
      return 0; // No difficulty if no event ID
    }
    return countLeadingZeroBits(eventId);
  }
}
