import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';

class TradeState {
  final Status status;
  final Action? action;
  final Order? order;

  TradeState({
    required this.status,
    required this.action,
    required this.order,
  });

  @override
  String toString() =>
      'TradeState(status: $status, action: $action, order: $order)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeState &&
          other.status == status &&
          other.action == action &&
          other.order == order;

  @override
  int get hashCode => Object.hash(status, action, order);

  TradeState copyWith({
    Status? status,
    Action? action,
    Order? order,
  }) {
    return TradeState(
      status: status ?? this.status,
      action: action ?? this.action,
      order: order ?? this.order,
    );
  }
}
