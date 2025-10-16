import 'package:mostro_mobile/data/models/payload.dart';
import 'package:mostro_mobile/data/models/order.dart';

class OrdersResponse implements Payload {
  final List<Order> orders;

  OrdersResponse({required this.orders});

  @override
  Map<String, dynamic> toJson() {
    return {
      'orders': orders.map((order) => order.toJson()['order']).toList(),
    };
  }

  factory OrdersResponse.fromJson(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('orders')) {
        throw FormatException('Missing required field: orders');
      }

      final ordersValue = json['orders'];
      if (ordersValue is! List) {
        throw FormatException('Field orders must be a List, got ${ordersValue.runtimeType}');
      }

      final orders = ordersValue
          .map((orderJson) => Order.fromJson(orderJson as Map<String, dynamic>))
          .toList();

      return OrdersResponse(orders: orders);
    } catch (e) {
      throw FormatException('Failed to parse OrdersResponse from JSON: $e');
    }
  }

  @override
  String get type => 'orders_response';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrdersResponse &&
           other.orders.length == orders.length;
  }

  @override
  int get hashCode => orders.hashCode;

  @override
  String toString() => 'OrdersResponse(orders: ${orders.length} orders)';
}
