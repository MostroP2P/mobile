import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/peer.dart';

/// Represents a User session
///
/// This class is used to store details of a user session
class Session {
  final NostrKeyPairs masterKey;
  final NostrKeyPairs tradeKey;
  final int keyIndex;
  final bool fullPrivacy;
  final DateTime startTime;
  String? orderId;
  OrderType? orderType;
  Peer? peer;

  Session({
    required this.masterKey,
    required this.tradeKey,
    required this.keyIndex,
    required this.fullPrivacy,
    required this.startTime,
    this.orderId,
    this.orderType,
    this.peer,
  });

  Map<String, dynamic> toJson() => {
        'trade_key': tradeKey.private,
        'key_index': keyIndex,
        'full_privacy': fullPrivacy,
        'start_time': startTime.toIso8601String(),
        'order_id': orderId,
        'order_type': orderType?.value,
        'peer': peer?.publicKey,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      masterKey: json['master_key'],
      tradeKey: json['trade_key'],
      keyIndex: json['key_index'],
      fullPrivacy: json['full_privacy'],
      startTime: DateTime.parse(json['start_time']),
      orderId: json['order_id'],
      orderType: json['order_type'] != null
          ? OrderType.fromString(json['order_type'])
          : null,
      peer: json['peer'] != null ? Peer(publicKey: json['peer']) : null,
    );
  }
}
