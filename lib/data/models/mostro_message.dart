import 'dart:convert';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payload.dart';
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

  Map<String, dynamic> toJson() {
    Map<String, dynamic> json = {
      'version': Config.mostroVersion,
      'request_id': requestId,
      'trade_index': tradeIndex,
    };
    if (id != null) {
      json['id'] = id;
    }
    json['action'] = action.value;
    json['payload'] = _payload?.toJson();
    return json;
  }

  factory MostroMessage.fromJson(Map<String, dynamic> json) {
    final timestamp = json['timestamp'];
    json = json['order'] ?? json['cant-do'] ?? json;
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

  String sign(NostrKeyPairs keyPair) {
    final message = {'order': toJson()};
    final serializedEvent = jsonEncode(message);
    final bytes = utf8.encode(serializedEvent);
    final digest = sha256.convert(bytes);
    final hash = hex.encode(digest.bytes);
    final signature = keyPair.sign(hash);
    return signature;
  }

  String serialize({NostrKeyPairs? keyPair}) {
    final message = {'order': toJson()};
    final serializedEvent = jsonEncode(message);
    final signature = (keyPair != null) ? '"${sign(keyPair)}"' : null;
    final content = '[$serializedEvent, $signature]';
    return content;
  }

  Future<NostrEvent> wrap({
    required NostrKeyPairs tradeKey,
    required String recipientPubKey,
    NostrKeyPairs? masterKey,
    int? keyIndex,
  }) async {
    this.tradeIndex = keyIndex;
    final content = serialize(keyPair: masterKey != null ? tradeKey : null);
    final keySet = masterKey ?? tradeKey;

    final encryptedContent = await NostrUtils.createRumor(
        tradeKey, keySet.private, recipientPubKey, content);

    final wrapperKeyPair = NostrUtils.generateKeyPair();

    String sealedContent = await NostrUtils.createSeal(
        keySet, wrapperKeyPair.private, recipientPubKey, encryptedContent);

    return await NostrUtils.createWrap(
        wrapperKeyPair, sealedContent, recipientPubKey);
  }
}
