import 'dart:convert';
import 'package:mostro_mobile/app/config.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class MostroMessage<T extends Payload> {
  String? requestId;
  final Action action;
  int? tradeIndex;
  T? _payload;

  MostroMessage(
      {required this.action, this.requestId, T? payload, this.tradeIndex})
      : _payload = payload;

  Map<String, dynamic> toJson() {
    return {
      'order': {
        'version': Config.mostroVersion,
        'request_id': requestId,
        'trade_index': tradeIndex,
        'action': action.value,
        'payload': _payload?.toJson(),
      },
    };
  }

  factory MostroMessage.deserialized(String data) {
    try {
      final decoded = jsonDecode(data);
      final event = decoded[0] as Map<String, dynamic>;
      final order = event['order'] != null
          ? event['order'] as Map<String, dynamic>
          : event['cant-do'] != null
              ? event['cant-do'] as Map<String, dynamic>
              : throw FormatException('Missing order object');

      final action = order['action'] != null
          ? Action.fromString(order['action'])
          : throw FormatException('Missing action field');

      final payload = order['payload'] != null
          ? Payload.fromJson(order['payload']) as T
          : null;

      final tradeIndex =
          order['trade_index'] != null ? int.parse(order['trade_index']) : null;

      return MostroMessage<T>(
        action: action,
        requestId: order['request_id'],
        payload: payload,
        tradeIndex: tradeIndex,
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
}
