import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/payload.dart';

/// Payload carried by [Action.addBondInvoice]. mostrod asks the non-slashed
/// counterparty for a bolt11 of `order.amount` sats; `slashedAt` (Unix
/// seconds) plus `bond_payout_claim_window_days` from kind-38385 gives the
/// forfeit deadline.
class BondPayoutRequest implements Payload {
  final Order order;
  final int slashedAt;

  BondPayoutRequest({
    required this.order,
    required this.slashedAt,
  });

  @override
  String get type => 'bond_payout_request';

  @override
  Map<String, dynamic> toJson() {
    // Order.toJson() wraps the fields under an 'order' key (`{order: {...}}`).
    // The mostrod wire ships the order's fields directly, so unwrap to keep
    // toJson/fromJson symmetric.
    final orderJson = order.toJson();
    final innerOrder =
        (orderJson['order'] as Map<String, dynamic>?) ?? orderJson;
    return {
      type: {
        'order': innerOrder,
        'slashed_at': slashedAt,
      },
    };
  }

  factory BondPayoutRequest.fromJson(Map<String, dynamic> json) {
    try {
      final orderJson = json['order'];
      if (orderJson is! Map<String, dynamic>) {
        throw FormatException(
            'Invalid order type: ${orderJson.runtimeType}');
      }

      final slashedAtValue = json['slashed_at'];
      final int slashedAt;
      if (slashedAtValue is int) {
        slashedAt = slashedAtValue;
      } else if (slashedAtValue is String) {
        slashedAt = int.tryParse(slashedAtValue) ??
            (throw FormatException('Invalid slashed_at format: $slashedAtValue'));
      } else {
        throw FormatException(
            'Invalid slashed_at type: ${slashedAtValue.runtimeType}');
      }

      return BondPayoutRequest(
        order: Order.fromJson(orderJson),
        slashedAt: slashedAt,
      );
    } catch (e) {
      throw FormatException('Failed to parse BondPayoutRequest from JSON: $e');
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BondPayoutRequest &&
        other.order == order &&
        other.slashedAt == slashedAt;
  }

  @override
  int get hashCode => Object.hash(order, slashedAt);

  @override
  String toString() => 'BondPayoutRequest(order: $order, slashedAt: $slashedAt)';
}
