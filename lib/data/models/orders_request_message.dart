import 'dart:convert';

class OrdersRequestMessage {
  final int version;
  final int requestId;
  final String action;
  final List<String> orderIds;

  OrdersRequestMessage({
    this.version = 1,
    required this.requestId,
    this.action = 'orders',
    required this.orderIds,
  });

  Map<String, dynamic> toJson() => {
        'order': {
          'version': version,
          'request_id': requestId,
          'action': action,
          'payload': {
            'ids': orderIds,
          },
        },
      };

  String toJsonString() => jsonEncode([toJson(), null]);
}
