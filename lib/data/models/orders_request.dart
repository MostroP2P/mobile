import 'package:collection/collection.dart';
import 'package:mostro_mobile/data/models/payload.dart';

class OrdersRequest implements Payload {
  final List<String> ids;

  OrdersRequest({required this.ids}) {
    if (ids.isEmpty) {
      throw ArgumentError('Order IDs list cannot be empty');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'ids': ids,
    };
  }

  factory OrdersRequest.fromJson(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('ids')) {
        throw FormatException('Missing required field: ids');
      }

      final idsValue = json['ids'];
      if (idsValue is! List) {
        throw FormatException('Field ids must be a List, got ${idsValue.runtimeType}');
      }

      final ids = idsValue.map((id) => id.toString()).toList();

      if (ids.isEmpty) {
        throw FormatException('Order IDs list cannot be empty');
      }

      return OrdersRequest(ids: ids);
    } catch (e) {
      throw FormatException('Failed to parse OrdersRequest from JSON: $e');
    }
  }

  @override
  String get type => 'orders_request';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrdersRequest &&
           const ListEquality().equals(other.ids, ids);
  }

  @override
  int get hashCode => const ListEquality().hash(ids);

  @override
  String toString() => 'OrdersRequest(ids: $ids)';
}
