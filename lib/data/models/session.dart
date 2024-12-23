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

  Map<String, dynamic> toJson() => {
        'startTime': startTime.toIso8601String(),
        'masterKey': masterKey.private,
        'tradeKey': tradeKey.private,
        'eventId': orderId,
        'keyIndex': keyIndex,
        'fullPrivacy': fullPrivacy,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      startTime: DateTime.parse(json['startTime']),
      masterKey: NostrKeyPairs(
        private: json['masterKey'],
      ),
      orderId: json['eventId'],
      keyIndex: int.parse(json['keyIndex']),
      tradeKey: NostrKeyPairs(private: json['tradeKey']),
      fullPrivacy: json['fullPrivacy'],
    );
  }
}
