import 'package:mostro_mobile/data/models/payload.dart';

class OrdersPayload implements Payload {
  final List<String> ids;

  const OrdersPayload({required this.ids});

  @override
  String get type => 'orders';

  factory OrdersPayload.fromJson(Map<String, dynamic> json) {
    return OrdersPayload(
      ids: (json['ids'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'ids': ids,
      };
}
