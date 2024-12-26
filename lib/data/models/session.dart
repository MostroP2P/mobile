import 'package:dart_nostr/dart_nostr.dart';

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

  Session(
      {required this.masterKey,
      required this.tradeKey,
      required this.keyIndex,
      required this.startTime,
      required this.fullPrivacy,
      this.orderId});

  // We don't store the keys in the session files
  Map<String, dynamic> toJson() => {
        'start_time': startTime.toIso8601String(),
        'event_id': orderId,
        'key_index': keyIndex,
        'full_privacy': fullPrivacy,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      startTime: DateTime.parse(json['start_time']),
      masterKey: json['master_key'],
      orderId: json['event_id'],
      keyIndex: json['key_index'],
      tradeKey: json['trade_key'],
      fullPrivacy: json['full_privacy'],
    );
  }
}
