import 'dart:convert';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/range_amount.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/rating.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:dart_nostr/dart_nostr.dart';

extension NostrEventExtensions on NostrEvent {
  String? get recipient => _getTagValue('p');
  String? get orderId => _getTagValue('d');
  OrderType? get orderType => _getTagValue('k') != null
      ? OrderType.fromString(_getTagValue('k')!)
      : null;
  String? get currency => _getTagValue('f');
  Status get status => Status.fromString(_getTagValue('s')!);
  String? get amount => _getTagValue('amt');
  RangeAmount get fiatAmount => _getAmount('fa');
  List<String> get paymentMethods {
    final tag = tags?.firstWhere((t) => t[0] == 'pm', orElse: () => []);
    if (tag != null && tag.length > 1) {
      return tag.sublist(1);
    }
    return [];
  }

  String? get premium => _getTagValue('premium');
  String? get source => _getTagValue('source');
  Rating? get rating => _getTagValue('rating') != null
      ? Rating.deserialized(_getTagValue('rating')!)
      : null;
  String? get network => _getTagValue('network');
  String? get layer => _getTagValue('layer');
  String? get name => _getTagValue('name') ?? 'Anon';
  String? get geohash => _getTagValue('g');
  String? get bond => _getTagValue('bond');
  String? get expiration => _timeAgo(_getTagValue('expiration'));
  String? timeAgoWithLocale(String? locale) =>
      _timeAgo(_getTagValue('expiration'), locale);
  DateTime get expirationDate => _getTimeStamp(_getTagValue('expiration')!);
  String? get platform => _getTagValue('y');
  String get type => _getTagValue('z')!;

  String? _getTagValue(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1) ? tag[1] : null;
  }

  RangeAmount _getAmount(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1)
        ? RangeAmount.fromList(tag)
        : RangeAmount.empty();
  }

  DateTime _getTimeStamp(String timestamp) {
    final ts = int.parse(timestamp);
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000)
        .subtract(Duration(hours: 12));
  }

  String _timeAgo(String? ts, [String? locale]) {
    if (ts == null) return "invalid date";
    final timestamp = int.tryParse(ts);
    if (timestamp != null && timestamp > 0) {
      final DateTime eventTime =
          DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
              .subtract(Duration(hours: 48));

      // Use provided locale or fallback to Spanish
      final effectiveLocale = locale ?? 'es';
      return timeago.format(eventTime,
          allowFromNow: true, locale: effectiveLocale);
    } else {
      return "invalid date";
    }
  }

  Future<NostrEvent> unWrap(String privateKey) async {
    return await NostrUtils.decryptNIP59Event(
      this,
      privateKey,
    );
  }

  /// Unwraps a Gift Wrap (kind 1059) following NIP-59 for Mostro dispute chat
  /// 
  /// Flow (as per mostro-cli):
  /// 1. Decrypt Gift Wrap (1059) with ephemeral_pubkey + receiver_private_key → SEAL (13)
  /// 2. Decrypt SEAL (13) with sender_pubkey + receiver_private_key → RUMOR (1, unsigned)
  /// 3. Return RUMOR with Mostro message content
  /// Helper to sanitize JSON for NostrEvent.deserialized
  /// Only sets empty strings for id and sig (which can be null in unsigned events)
  /// Preserves other fields as-is to avoid breaking validation
  String _sanitizeEventJson(String eventJson) {
    try {
      final Map<String, dynamic> eventMap = jsonDecode(eventJson);
      
      // Only sanitize id and sig - these can be null in RUMORs (unsigned events)
      // Don't touch pubkey or content as they have validation that requires real values
      if (eventMap['id'] == null) {
        eventMap['id'] = '';
      }
      if (eventMap['sig'] == null) {
        eventMap['sig'] = '';
      }
      
      return jsonEncode(eventMap);
    } catch (e) {
      // If parsing fails, return original
      return eventJson;
    }
  }

  Future<NostrEvent> mostroUnWrap(NostrKeyPairs receiver) async {
    if (kind != 1059) {
      throw ArgumentError('Expected kind 1059 (Gift Wrap), got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Gift Wrap content is empty');
    }

    try {
      // STEP 1: Decrypt Gift Wrap with ephemeral key
      // The Gift Wrap pubkey is the ephemeral public key
      final ephemeralPubkey = pubkey; // From the Gift Wrap event
      
      try {
        final decryptedSeal = await NostrUtils.decryptNIP44(
          content!,
          receiver.private,
          ephemeralPubkey,
        );

        final sanitizedSeal = _sanitizeEventJson(decryptedSeal);
        final sealEvent = NostrEvent.deserialized(
          '["EVENT", "", $sanitizedSeal]',
        );

        // STEP 2: Verify it's a SEAL (kind 13)
        if (sealEvent.kind != 13) {
          throw Exception('Expected SEAL (kind 13), got: ${sealEvent.kind}');
        }

        if (sealEvent.content == null || sealEvent.content!.isEmpty) {
          throw Exception('SEAL content is empty');
        }

        // STEP 3: Decrypt SEAL with sender's pubkey (from SEAL)
        // The SEAL pubkey identifies the actual sender (admin or user)
        final senderPubkey = sealEvent.pubkey;
        
        final decryptedRumor = await NostrUtils.decryptNIP44(
          sealEvent.content!,
          receiver.private,
          senderPubkey,
        );

        final sanitizedRumor = _sanitizeEventJson(decryptedRumor);
        final rumorEvent = NostrEvent.deserialized(
          '["EVENT", "", $sanitizedRumor]',
        );

        // STEP 4: Verify it's a RUMOR (kind 1, unsigned)
        if (rumorEvent.kind != 1) {
          throw Exception('Expected RUMOR (kind 1), got: ${rumorEvent.kind}');
        }

        return rumorEvent;
      } catch (e) {
        // Add more context about which step failed
        if (e.toString().contains('type cast')) {
          throw Exception('Type cast error during unwrap - likely null value in event structure: $e');
        }
        rethrow;
      }
    } catch (e) {
      throw Exception('Failed to unwrap Mostro chat message: $e');
    }
  }

  /// Wraps a RUMOR (kind 1) into a Gift Wrap (kind 1059) following NIP-59
  /// 
  /// Flow (as per mostro-cli):
  /// 1. Create RUMOR (kind 1, unsigned) with Mostro message content
  /// 2. Encrypt RUMOR with sender_private_key + receiver_pubkey → SEAL (13)
  /// 3. Encrypt SEAL with ephemeral_key + receiver_pubkey → Gift Wrap (1059)
  /// 
  /// Parameters:
  /// - senderKeys: The sender's key pair (trade keys)
  /// - receiverPubkey: The receiver's public key (admin pubkey for disputes)
  Future<NostrEvent> mostroWrap(NostrKeyPairs senderKeys, String receiverPubkey) async {
    if (kind != 1) {
      throw ArgumentError('Expected kind 1 (RUMOR), got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('RUMOR content is empty');
    }

    try {
      // STEP 1: Prepare the RUMOR (already a kind 1 event, unsigned)
      // The rumor should NOT have an 'id' or 'sig' field
      final rumorMap = {
        'kind': 1,
        'content': content,
        'pubkey': senderKeys.public,
        'created_at': ((createdAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000),
        'tags': tags ?? [],
      };

      final rumorJson = jsonEncode(rumorMap);

      // STEP 2: Create SEAL (kind 13)
      // Encrypt the rumor with sender's private key + receiver's public key
      final encryptedRumor = await NostrUtils.encryptNIP44(
        rumorJson,
        senderKeys.private,
        receiverPubkey,
      );

      final seal = NostrEvent.fromPartialData(
        kind: 13,
        content: encryptedRumor,
        keyPairs: senderKeys,
        tags: [], // SEAL always has empty tags
        createdAt: DateTime.now(),
      );

      final sealJson = jsonEncode(seal.toMap());

      // STEP 3: Create Gift Wrap (kind 1059)
      // Generate ephemeral key pair (single-use)
      final ephemeralKeyPair = NostrUtils.generateKeyPair();

      // Encrypt the seal with ephemeral key + receiver's public key
      final encryptedSeal = await NostrUtils.encryptNIP44(
        sealJson,
        ephemeralKeyPair.private,
        receiverPubkey,
      );

      // Create Gift Wrap with randomized timestamp (±2 days)
      final giftWrap = NostrEvent.fromPartialData(
        kind: 1059,
        content: encryptedSeal,
        keyPairs: ephemeralKeyPair,
        tags: [
          ["p", receiverPubkey], // Identifies the receiver
        ],
        createdAt: _randomizedTimestamp(),
      );

      return giftWrap;
    } catch (e) {
      throw Exception('Failed to wrap Mostro chat message: $e');
    }
  }

  DateTime _randomizedTimestamp() {
    final now = DateTime.now();
    final randomSeconds = (DateTime.now().millisecondsSinceEpoch % 172800);
    return now.subtract(Duration(seconds: randomSeconds));
  }

  /// Wraps a RUMOR (kind 1) into a Gift Wrap (kind 1059) with separate keys for RUMOR and SEAL
  ///
  /// This is used for Mostro restore-session and similar operations where:
  /// - RUMOR is signed with trade key (index 0)
  /// - SEAL is signed with master key (identity key)
  ///
  /// Flow:
  /// 1. Create RUMOR (kind 1, unsigned) with rumor keys
  /// 2. Encrypt RUMOR with seal keys → SEAL (13)
  /// 3. Encrypt SEAL with ephemeral key → Gift Wrap (1059)
  ///
  /// Parameters:
  /// - rumorKeys: The keys used to sign the rumor (trade key)
  /// - sealKeys: The keys used to sign the seal (master/identity key)
  /// - receiverPubkey: The receiver's public key (Mostro pubkey)
  Future<NostrEvent> mostroWrapWithSeparateKeys({
    required NostrKeyPairs rumorKeys,
    required NostrKeyPairs sealKeys,
    required String receiverPubkey,
  }) async {
    if (kind != 1) {
      throw ArgumentError('Expected kind 1 (RUMOR), got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('RUMOR content is empty');
    }

    try {
      // STEP 1: Prepare the RUMOR (kind 1, unsigned) with rumor keys
      final rumorMap = {
        'kind': 1,
        'content': content,
        'pubkey': rumorKeys.public,
        'created_at': ((createdAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000),
        'tags': tags ?? [],
      };

      final rumorJson = jsonEncode(rumorMap);

      // STEP 2: Create SEAL (kind 13) signed with SEAL KEYS
      // Encrypt the rumor with seal private key + receiver's public key
      final encryptedRumor = await NostrUtils.encryptNIP44(
        rumorJson,
        sealKeys.private,
        receiverPubkey,
      );

      final seal = NostrEvent.fromPartialData(
        kind: 13,
        content: encryptedRumor,
        keyPairs: sealKeys, // Use seal keys (master/identity key)
        tags: [],
        createdAt: DateTime.now(),
      );

      final sealJson = jsonEncode(seal.toMap());

      // STEP 3: Create Gift Wrap (kind 1059)
      // Generate ephemeral key pair (single-use)
      final ephemeralKeyPair = NostrUtils.generateKeyPair();

      // Encrypt the seal with ephemeral key + receiver's public key
      final encryptedSeal = await NostrUtils.encryptNIP44(
        sealJson,
        ephemeralKeyPair.private,
        receiverPubkey,
      );

      // Create Gift Wrap with randomized timestamp
      final giftWrap = NostrEvent.fromPartialData(
        kind: 1059,
        content: encryptedSeal,
        keyPairs: ephemeralKeyPair,
        tags: [
          ["p", receiverPubkey],
        ],
        createdAt: _randomizedTimestamp(),
      );

      return giftWrap;
    } catch (e) {
      throw Exception('Failed to wrap with separate keys: $e');
    }
  }

  /// P2P Chat: Simplified NIP-59 wrapper for peer-to-peer chat
  /// Wraps a signed kind 1 event directly in a kind 1059 wrapper
  /// This is different from mostroWrap which uses a SEAL intermediate layer
  /// 
  /// According to Mostro documentation:
  /// 1. Inner event is kind 1, signed by sender
  /// 2. Wrapper is kind 1059, encrypted with ephemeral key
  /// 3. No SEAL (kind 13) intermediate layer
  Future<NostrEvent> p2pWrap(NostrKeyPairs senderKeys, String receiverPubkey) async {
    if (kind != 1) {
      throw ArgumentError('Expected kind 1 event for P2P chat, got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Message content is empty');
    }

    try {
      // The inner event must be signed by the sender
      // This is already done when creating the event with fromPartialData
      final innerEventJson = jsonEncode(toMap());

      // Generate ephemeral key pair (single-use for this message)
      final ephemeralKeyPair = NostrUtils.generateKeyPair();

      // Encrypt the inner event with ephemeral key + receiver's public key
      final encryptedContent = await NostrUtils.encryptNIP44(
        innerEventJson,
        ephemeralKeyPair.private,
        receiverPubkey,
      );

      // Create wrapper (kind 1059) with randomized timestamp
      final wrapper = NostrEvent.fromPartialData(
        kind: 1059,
        content: encryptedContent,
        keyPairs: ephemeralKeyPair,
        tags: [
          ["p", receiverPubkey], // Identifies the receiver (shared key pubkey)
        ],
        createdAt: _randomizedTimestamp(),
      );

      return wrapper;
    } catch (e) {
      throw Exception('Failed to wrap P2P chat message: $e');
    }
  }

  /// P2P Chat: Unwrap a simplified NIP-59 wrapper for peer-to-peer chat
  /// Decrypts a kind 1059 wrapper to extract the signed kind 1 inner event
  /// This is different from mostroUnWrap which expects a SEAL intermediate layer
  Future<NostrEvent> p2pUnwrap(NostrKeyPairs receiver) async {
    if (kind != 1059) {
      throw ArgumentError('Expected kind 1059 (Gift Wrap), got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Gift Wrap content is empty');
    }

    try {
      // The wrapper pubkey is the ephemeral public key
      final ephemeralPubkey = pubkey;

      // Decrypt the wrapper with receiver's private key + ephemeral public key
      final decryptedContent = await NostrUtils.decryptNIP44(
        content!,
        receiver.private,
        ephemeralPubkey,
      );

      // Parse the inner event
      final sanitizedJson = _sanitizeEventJson(decryptedContent);
      final innerEvent = NostrEvent.deserialized(
        '["EVENT", "", $sanitizedJson]',
      );

      // Verify it's a kind 1 event
      if (innerEvent.kind != 1) {
        throw Exception('Expected kind 1 inner event, got: ${innerEvent.kind}');
      }

      // Verify the signature of the inner event
      if (innerEvent.id == null || innerEvent.sig == null) {
        throw Exception('Inner event is not properly signed');
      }

      // The inner event is already verified by deserialized()
      return innerEvent;
    } catch (e) {
      throw Exception('Failed to unwrap P2P chat message: $e');
    }
  }

  NostrEvent copy() {
    return NostrEvent(
      content: content,
      createdAt: createdAt,
      id: id,
      kind: kind,
      pubkey: pubkey,
      sig: sig,
      tags: tags,
    );
  }

  static NostrEvent fromMap(Map<String, dynamic> event) {
    return NostrEvent(
      id: event['id'] as String,
      kind: event['kind'] as int,
      content: event['content'] == null ? '' : event['content'] as String,
      sig: event['sig'] as String,
      pubkey: event['pubkey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int) * 1000,
      ),
      tags: List<List<String>>.from(
        (event['tags'] as List)
            .map(
              (nestedElem) => (nestedElem as List)
                  .map(
                    (nestedElemContent) => nestedElemContent.toString(),
                  )
                  .toList(),
            )
            .toList(),
      ),
    );
  }
}
