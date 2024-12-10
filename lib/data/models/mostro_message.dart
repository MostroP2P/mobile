import 'dart:convert';

import 'package:mostro_mobile/app/config.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class MostroMessage<T extends Payload> {
  String? requestId;
  final Action action;
  T? _payload;

  MostroMessage({required this.action, this.requestId, T? payload})
      : _payload = payload;

  Map<String, dynamic> toJson() {
    return {
      'order': {
        'version': Config.mostroVersion,
        'id': requestId,
        'action': action.value,
        'content': _payload?.toJson(),
      },
    };
  }

  factory MostroMessage.deserialized(String data) {
    try {
      final decoded = jsonDecode(data);
      final event = decoded as Map<String, dynamic>;
      final order = event['order'] != null
          ? event['order'] as Map<String, dynamic>
          : throw FormatException('Missing order object');

      final action = order['action'] != null
          ? Action.fromString(order['action'])
          : throw FormatException('Missing action field');

      final content = order['content'] != null
          ? Payload.fromJson(event['order']['content']) as T
          : null;

      return MostroMessage<T>(
        action: action,
        requestId: order['id'],
        payload: content,
      );
    } catch (e) {
      throw FormatException('Failed to deserialize MostroMessage: $e');
    }
  }

  T? get payload => _payload;

  T? getPayload() {
    return _payload as T;
  }
}
