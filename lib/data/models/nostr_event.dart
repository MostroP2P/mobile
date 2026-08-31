import 'package:nip44/nip44.dart';
import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/range_amount.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/rating.dart';
import 'package:mostro_mobile/shared/utils/chat_keys.dart';
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
  String? timeAgoWithLocale(String locale) =>
      _timeAgoFromCreated(locale);
  DateTime get expirationDate => _getTimeStamp(_getTagValue('expiration')!);
  String? get expiresAt => _getTagValue('expires_at');
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


  String _timeAgoFromCreated(String locale) {
    if (createdAt == null) return "invalid date";
    return timeago.format(createdAt!, allowFromNow: true, locale: locale);
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
          // One-shot wrapper pubkey: keep it out of the conversation cache.
          cacheConversationKey: false,
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
        // Single-use ephemeral key: keep it out of the conversation cache.
        cacheConversationKey: false,
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

  /// Legacy chat: unwrap the pre-migration 1-layer gift wrap (kind 1059).
  /// Kept only to read chat history stored on disk before the kind-14
  /// envelope (chatWrap/chatUnwrap) replaced this format on the wire.
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
        // One-shot wrapper pubkey: keep it out of the conversation cache.
        cacheConversationKey: false,
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

  /// Mostro chat envelope (kind 14): tolerated clock skew in seconds between
  /// inner/outer timestamps and against the local clock. Spec default: 60.
  static const chatMaxClockSkewSecs = 60;

  /// Mostro chat envelope (kind 14): upper bound on the encrypted outer
  /// content, enforced before decrypting. Spec default: 64 KiB.
  static const chatMaxContentBytes = 64 * 1024;

  /// Mostro chat envelope (kind 14): default subscription lookback window,
  /// matching the spec default (7 days).
  static const chatDefaultLookback = Duration(days: 7);

  /// Mostro chat envelope (kind 14): default subscription event limit.
  static const chatDefaultLimit = 100;

  /// Mostro chat: on-disk record for a peer chat envelope, keyed by order.
  /// Shared by the foreground notifier and the background isolate so both
  /// write the shape `_loadHistoricalMessages` expects.
  Map<String, dynamic> peerChatRecord(String orderId) => {
        ..._chatRecordFields(),
        'type': 'chat',
        'order_id': orderId,
      };

  /// Mostro chat: on-disk record for a dispute chat envelope, keyed by dispute.
  Map<String, dynamic> disputeChatRecord(String disputeId) => {
        ..._chatRecordFields(),
        'type': 'dispute_chat',
        'dispute_id': disputeId,
      };

  Map<String, dynamic> _chatRecordFields() => {
        'id': id,
        'created_at': createdAt!.millisecondsSinceEpoch ~/ 1000,
        'kind': kind,
        'content': content,
        'pubkey': pubkey,
        'sig': sig,
        'tags': tags,
      };

  /// Mostro chat: subscription filter for one or more conversations, matched
  /// by their K_sign authors (never by `#p`, which a third party could flood).
  /// Shared by the foreground subscriptions and the background isolate so the
  /// two cannot drift into different backlog bounds.
  static NostrFilter chatSubscriptionFilter({
    required List<String> signPubkeys,
    required DateTime since,
  }) {
    return NostrFilter(
      kinds: [14],
      authors: signPubkeys,
      since: since,
      limit: chatDefaultLimit,
    );
  }

  /// Mostro chat: build the signed kind 1 inner event for a chat message.
  /// A random `u` nonce tag keeps same-second identical texts from
  /// colliding into one inner id, which dedup would drop as a replay.
  static NostrEvent createChatRumor({
    required NostrKeyPairs senderKeys,
    required String content,
    DateTime? createdAt,
  }) {
    return NostrEvent.fromPartialData(
      keyPairs: senderKeys,
      content: content,
      kind: 1,
      tags: [
        ["u", _chatNonceHex()],
      ],
      createdAt: createdAt,
    );
  }

  /// 8 random bytes as 16 hex chars, from a cryptographic source.
  static String _chatNonceHex() {
    final rng = Random.secure();
    return List.generate(
      8,
      (_) => rng.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Mostro chat: wrap this signed kind 1 event into a kind 14 envelope
  /// signed by `K_sign`, NIP-44 self-encrypted under `K_conv`.
  /// Supersedes the legacy 1-layer gift wrap (kind 1059) for dispute and
  /// peer chat; p2pUnwrap remains only to read stored pre-migration history.
  ///
  /// The outer event shares this event's timestamp (recipients reject a
  /// mismatch) and carries exactly one `p` tag = pub(K_conv).
  /// Spec: https://mostro.network/protocol/chat.html
  Future<NostrEvent> chatWrap(ChatKeys chatKeys) async {
    if (kind != 1) {
      throw ArgumentError('Expected kind 1 event for chat, got: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Message content is empty');
    }

    if (id == null || sig == null) {
      throw ArgumentError('Inner chat event must be signed');
    }

    // NIP-44 self-encryption: K_conv is both sides of the key exchange
    final encryptedContent = await NostrUtils.encryptNIP44(
      jsonEncode(toMap()),
      chatKeys.conv.private,
      chatKeys.conv.public,
    );

    return NostrEvent.fromPartialData(
      kind: 14,
      content: encryptedContent,
      keyPairs: chatKeys.sign,
      tags: [
        ["p", chatKeys.conv.public],
      ],
      createdAt: createdAt,
    );
  }

  /// Mostro chat: unwrap a kind 14 envelope signed by `K_sign` and return
  /// the verified inner kind 1 event.
  ///
  /// Runs the mandatory spec checks cheapest-first. [allowedSigners] are the
  /// accepted inner pubkeys (trade key + admin pubkey for dispute chat).
  /// The caller still owns rate limiting and duplicate detection.
  /// [now] overrides the local clock for testing.
  Future<NostrEvent> chatUnwrap(
    ChatKeys chatKeys,
    List<String> allowedSigners, {
    DateTime? now,
  }) async {
    // 1-2. Outer author and kind
    if (pubkey != chatKeys.sign.public) {
      throw Exception(
        'Outer event is not authored by the conversation signing key',
      );
    }

    if (kind != 14) {
      throw Exception('Expected kind 14 chat event, got: $kind');
    }

    // 3. Exactly one p tag equal to pub(K_conv)
    final pTags =
        (tags ?? []).where((t) => t.isNotEmpty && t[0] == 'p').toList();
    if (pTags.length != 1 ||
        pTags[0].length < 2 ||
        pTags[0][1] != chatKeys.conv.public) {
      throw Exception(
        'Outer event must carry exactly one p tag for this conversation',
      );
    }

    // 4. Absolute timestamp bound against the local clock
    final localNow = now ?? DateTime.now();
    if (createdAt == null ||
        createdAt!.isAfter(
          localNow.add(const Duration(seconds: chatMaxClockSkewSecs)),
        )) {
      throw Exception('Outer event is dated too far in the future');
    }

    // 5. Size bound before any crypto
    if (content == null || content!.isEmpty) {
      throw Exception('Chat event content is empty');
    }
    if (utf8.encode(content!).length > chatMaxContentBytes) {
      throw Exception('Encrypted payload exceeds the accepted size');
    }

    // 6-11. Heavy part (two Schnorr verifications + NIP-44 decrypt, ~5 EC
    // multiplications) runs off the main isolate. The cached conversation
    // key is resolved here so the worker skips ECDH + HKDF; the outer event,
    // key material and thrown errors transfer across the boundary.
    final conversationKey = NostrUtils.conversationKeyFor(
      chatKeys.conv.private,
      chatKeys.conv.public,
    );
    final outer = this;
    final convPriv = chatKeys.conv.private;
    final convPub = chatKeys.conv.public;
    return Isolate.run(
      () => _chatUnwrapHeavy(
        outer,
        convPriv,
        convPub,
        conversationKey,
        allowedSigners,
      ),
    );
  }

  /// Steps 6-11 of [chatUnwrap], executed inside Isolate.run.
  static Future<NostrEvent> _chatUnwrapHeavy(
    NostrEvent outer,
    String convPriv,
    String convPub,
    Uint8List conversationKey,
    List<String> allowedSigners,
  ) async {
    // 6. Outer id and signature
    _verifyEventIntegrity(outer, 'outer');

    // 7. Decrypt (NIP-44 self-decryption under K_conv)
    final decrypted = await Nip44.decryptMessage(
      outer.content!,
      convPriv,
      convPub,
      customConversationKey: conversationKey,
    );

    final dynamic decoded;
    try {
      decoded = jsonDecode(decrypted);
    } catch (e) {
      throw Exception('Malformed inner chat event: $e');
    }
    if (decoded is! Map<String, dynamic>) {
      throw Exception('Malformed inner chat event');
    }
    // fromMap casts fields without null checks; normalize a missing-field
    // TypeError into the same Exception as malformed JSON
    final NostrEvent inner;
    try {
      inner = NostrEventExtensions.fromMap(decoded);
    } catch (e) {
      throw Exception('Malformed inner chat event: $e');
    }

    // 8. Inner id and signature (sender authentication)
    _verifyEventIntegrity(inner, 'inner');

    // 9. Inner signer allowlist
    if (!allowedSigners.contains(inner.pubkey)) {
      throw Exception(
        'Inner event is signed by a key that is not a party to this conversation',
      );
    }

    // 10. Inner kind
    if (inner.kind != 1) {
      throw Exception('Inner chat event is not a kind 1 text note');
    }

    // 11. Relative timestamp bound (stale re-wrap defense)
    final skew = (inner.createdAt!.millisecondsSinceEpoch ~/ 1000 -
            outer.createdAt!.millisecondsSinceEpoch ~/ 1000)
        .abs();
    if (skew > chatMaxClockSkewSecs) {
      throw Exception('Inner and outer timestamps disagree');
    }

    return inner;
  }

  /// Verify that an event's id matches its content and its signature is
  /// valid — both required, since a BIP-340 signature only covers the id.
  static void _verifyEventIntegrity(NostrEvent event, String label) {
    if (event.id == null ||
        event.sig == null ||
        event.kind == null ||
        event.createdAt == null) {
      throw Exception('The $label chat event is not properly signed');
    }

    final expectedId = NostrEvent.getEventId(
      kind: event.kind!,
      content: event.content ?? '',
      createdAt: event.createdAt!,
      tags: event.tags ?? [],
      pubkey: event.pubkey,
    );
    if (expectedId != event.id) {
      throw Exception('The $label chat event id does not match its content');
    }

    if (!NostrKeyPairs.verify(event.pubkey, event.id!, event.sig!)) {
      throw Exception('Invalid $label chat event signature');
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
