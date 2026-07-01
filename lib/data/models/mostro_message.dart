import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class MostroMessage<T extends Payload> {
  String? id;
  int? requestId;
  final Action action;
  int? tradeIndex;
  T? _payload;
  int? timestamp;

  MostroMessage({
    required this.action,
    this.requestId,
    this.id,
    T? payload,
    this.tradeIndex,
    this.timestamp,
  }) : _payload = payload;

  Map<String, dynamic> toJson({int? version}) {
    Map<String, dynamic> json = {
      'version': version ?? Config.mostroVersion,
      'request_id': requestId,
      'trade_index': tradeIndex,
    };
    if (id != null) {
      json['id'] = id;
    }
    json['action'] = action.value;
    // Serialize EmptyPayload as null to match protocol specification
    json['payload'] = (_payload is EmptyPayload) ? null : _payload?.toJson();
    return json;
  }

  factory MostroMessage.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    // IMPORTANT : Use 'order', 'restore' or 'cant-do' key as per protocol
    json = json['order'] ?? json['restore'] ?? json['cant-do'] ?? json;
    final num requestId = json['request_id'] ?? 0;

    return MostroMessage(
      action: Action.fromString(json['action']),
      requestId: requestId.toInt(),
      tradeIndex: json['trade_index'],
      id: json['id'],
      payload: json['payload'] != null
          ? Payload.fromJson(json['payload']) as T?
          : null,
      timestamp: timestamp,
    );
  }

  factory MostroMessage.deserialized(String json) {
    try {
      final data = jsonDecode(json);
      final order = (data is List)
          ? data[0] as Map<String, dynamic>
          : data as Map<String, dynamic>;

      final action = order['action'] != null
          ? Action.fromString(order['action'])
          : throw FormatException('Missing action field');

      final payload = order['payload'] != null
          ? Payload.fromJson(order['payload']) as T
          : null;

      final num tradeIndex = order['trade_index'] ?? 0;
      final num requestId = order['request_id'] ?? 0;

      return MostroMessage<T>(
        action: action,
        requestId: requestId.toInt(),
        id: order['id'],
        payload: payload,
        tradeIndex: tradeIndex.toInt(),
      );
    } catch (e) {
      throw FormatException('Failed to deserialize MostroMessage: $e');
    }
  }

  T? get payload => _payload;

  R? getPayload<R>() {
    if (payload is R) {
      return payload as R;
    }
    return null;
  }

  /// Wrapper key for the message envelope: 'restore' for restore and
  /// last-trade-index actions, 'order' for everything else, as per protocol.
  /// Single source of truth — it is load-bearing for the signature, so the
  /// signed content must be identical across sign/serialize/wrapNip44.
  String get _wrapperKey =>
      action == Action.restore || action == Action.lastTradeIndex
      ? 'restore'
      : 'order';

  String sign(NostrKeyPairs keyPair, {int? version}) {
    final message = {_wrapperKey: toJson(version: version)};
    final serializedEvent = jsonEncode(message);
    return _mostroSign(serializedEvent, keyPair);
  }

  /// Signs a UTF-8 string the Mostro way: SHA-256 digest, hex-encoded, then
  /// Schnorr-signed. Shared by the message [sign] and the protocol-v2 identity
  /// proof so both produce signatures the daemon can verify identically.
  String _mostroSign(String message, NostrKeyPairs keyPair) {
    final bytes = utf8.encode(message);
    final digest = sha256.convert(bytes);
    final hash = hex.encode(digest.bytes);
    return keyPair.sign(hash);
  }

  String serialize({NostrKeyPairs? keyPair, int? version}) {
    final message = {_wrapperKey: toJson(version: version)};
    final serializedEvent = jsonEncode(message);
    final signature =
        (keyPair != null) ? '"${sign(keyPair, version: version)}"' : null;
    final content = '[$serializedEvent, $signature]';
    return content;
  }

  Future<NostrEvent> wrap({
    required NostrKeyPairs tradeKey,
    required String recipientPubKey,
    NostrKeyPairs? masterKey,
    int? keyIndex,
    int difficulty = 0,
  }) async {
    tradeIndex = keyIndex;
    final content = serialize(keyPair: masterKey != null ? tradeKey : null);
    final keySet = masterKey ?? tradeKey;

    final encryptedContent = await NostrUtils.createRumor(
      tradeKey,
      keySet.private,
      recipientPubKey,
      content,
    );

    final wrapperKeyPair = NostrUtils.generateKeyPair();

    String sealedContent = await NostrUtils.createSeal(
      keySet,
      wrapperKeyPair.private,
      recipientPubKey,
      encryptedContent,
    );

    return await NostrUtils.createWrap(
      wrapperKeyPair,
      sealedContent,
      recipientPubKey,
      difficulty: difficulty,
    );
  }

  /// Wraps the message for protocol v2 (NIP-44 direct, kind 14).
  ///
  /// Produces the 3-tuple `[message, tradeSig, identityProof]` (§3.3), NIP-44
  /// encrypts it toward [recipientPubKey] with the trade key, and emits a
  /// kind-14 event **signed by the trade key** carrying a `p` tag. Mirrors
  /// `mostro-core`'s `transport.rs` wrap:
  /// - the message JSON carries `version: 2`;
  /// - in reputation mode (master key present) `tradeSig` is the trade-key
  ///   signature over the message and `identityProof` is
  ///   `[identityPubkey, sig]` where the signature is over
  ///   `mostro-transport-v2-identity:<tradePubkey>:<messageJSON>` made with the
  ///   master key;
  /// - in full-privacy mode (no master key) both are `null`.
  ///
  /// PoW (NIP-13), when [difficulty] > 0, is mined on the kind-14 event id and
  /// signed by the trade key — the first-contact lane is preserved.
  Future<NostrEvent> wrapNip44({
    required NostrKeyPairs tradeKey,
    required String recipientPubKey,
    NostrKeyPairs? masterKey,
    int? keyIndex,
    int difficulty = 0,
  }) async {
    tradeIndex = keyIndex;

    final messageMap = {_wrapperKey: toJson(version: 2)};
    final messageJson = jsonEncode(messageMap);

    // Reputation mode binds the identity; full privacy omits both signatures.
    final String? tradeSig =
        masterKey != null ? _mostroSign(messageJson, tradeKey) : null;

    List<String>? identityProof;
    if (masterKey != null) {
      final payload =
          'mostro-transport-v2-identity:${tradeKey.public}:$messageJson';
      identityProof = [masterKey.public, _mostroSign(payload, masterKey)];
    }

    final tuple = jsonEncode([messageMap, tradeSig, identityProof]);

    final encrypted = await NostrUtils.encryptNIP44(
      tuple,
      tradeKey.private,
      recipientPubKey,
    );

    final event = NostrEvent.fromPartialData(
      kind: 14,
      content: encrypted,
      keyPairs: tradeKey,
      tags: [
        ['p', recipientPubKey],
      ],
      createdAt: DateTime.now(),
    );

    if (difficulty > 0) {
      return NostrUtils.mineProofOfWork(event, difficulty, tradeKey);
    }
    return event;
  }

  /// Wraps the message for the transport advertised by the node's
  /// [protocolVersion] (§5 Phase B): v2 (NIP-44 direct, kind 14) via
  /// [wrapNip44] or v1 (gift wrap, kind 1059) via [wrap].
  ///
  /// Single entry point so every outbound Mostro send — order actions, restore
  /// requests, dispute creation — selects the transport consistently from the
  /// connected node, instead of hard-coding the v1 path.
  Future<NostrEvent> wrapForTransport({
    required int? protocolVersion,
    required NostrKeyPairs tradeKey,
    required String recipientPubKey,
    NostrKeyPairs? masterKey,
    int? keyIndex,
    int difficulty = 0,
  }) {
    switch (resolveTransport(protocolVersion)) {
      case Transport.nip44:
        return wrapNip44(
          tradeKey: tradeKey,
          recipientPubKey: recipientPubKey,
          masterKey: masterKey,
          keyIndex: keyIndex,
          difficulty: difficulty,
        );
      case Transport.giftWrap:
        return wrap(
          tradeKey: tradeKey,
          recipientPubKey: recipientPubKey,
          masterKey: masterKey,
          keyIndex: keyIndex,
          difficulty: difficulty,
        );
    }
  }
}
