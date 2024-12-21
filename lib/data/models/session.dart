import 'package:dart_nostr/dart_nostr.dart';

/// Represents a User session
///
/// This class is used to store details of a user session
/// which is connected to a single Buy/Sell order and is
/// persisted for a maximum of 48hrs or until the order is
/// completed
class Session {
  final String sessionId;
  final DateTime startTime;
  final NostrKeyPairs keyPair;
  String? eventId;

  Session({
    required this.sessionId,
    required this.startTime,
    required this.keyPair,
    this.eventId,
  });

  Map<String, dynamic> toJson() => {
        'sessionId': sessionId,
        'startTime': startTime.toIso8601String(),
        'privateKey': keyPair.private,
        'publicKey': keyPair.public,
        'eventId': eventId,
      };

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      sessionId: json['sessionId'],
      startTime: DateTime.parse(json['startTime']),
      keyPair: NostrKeyPairs(
        private: json['privateKey'],
      ),
      eventId: json['eventId'],
    );
  }

  String get privateKey => keyPair.private;
  String get publicKey => keyPair.public;
}
