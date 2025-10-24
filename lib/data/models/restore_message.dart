import 'dart:convert';

class RestoreMessage {
  final int version;
  final String action;

  RestoreMessage({
    this.version = 1,
    this.action = 'restore-session',
  });

  Map<String, dynamic> toJson() => {
        'restore': {
          'version': version,
          'action': action,
          'payload': null,
        }
      };

  String toJsonString() => jsonEncode(toJson());
}