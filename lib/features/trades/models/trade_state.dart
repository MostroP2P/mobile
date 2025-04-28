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
}
