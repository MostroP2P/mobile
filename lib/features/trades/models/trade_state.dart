import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/models/enums/action.dart' as actions;

class TradeState {
  final Status status;
  final actions.Action? lastAction;
  final Order? orderPayload;

  TradeState({
    required this.status,
    required this.lastAction,
    required this.orderPayload,
  });

  @override
  String toString() =>
      'TradeState(status: $status, lastAction: $lastAction, orderPayload: $orderPayload)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TradeState &&
          other.status == status &&
          other.lastAction == lastAction &&
          other.orderPayload == orderPayload;

  @override
  int get hashCode => Object.hash(status, lastAction, orderPayload);

  TradeState copyWith({
    Status? status,
    actions.Action? lastAction,
    Order? orderPayload,
  }) {
    return TradeState(
      status: status ?? this.status,
      lastAction: lastAction ?? this.lastAction,
      orderPayload: orderPayload ?? this.orderPayload,
    );
  }
}
