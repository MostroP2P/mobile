import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/enums.dart';

class OrderState {
  final Status status;
  final Action action;
  final Order? order;
  final PaymentRequest? paymentRequest;
  final CantDo? cantDo;
  final Dispute? dispute;

  OrderState({
    required this.status,
    required this.action,
    required this.order,
    this.paymentRequest,
    this.cantDo,
    this.dispute,
  });

factory OrderState.fromMostroMessage(MostroMessage message) {
  return OrderState(
    status: message.getPayload<Order>()?.status ?? Status.pending,
    action: message.action,
    order: message.getPayload<Order>(),
    paymentRequest: message.getPayload<PaymentRequest>(),
    cantDo: message.getPayload<CantDo>(),
    dispute: message.getPayload<Dispute>(),
  );
}

  @override
  String toString() =>
      'OrderState(status: $status, action: $action, order: $order, paymentRequest: $paymentRequest, cantDo: $cantDo, dispute: $dispute)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderState &&
          other.status == status &&
          other.action == action &&
          other.order == order &&
          other.paymentRequest == paymentRequest &&
          other.cantDo == cantDo &&
          other.dispute == dispute;

  @override
  int get hashCode => Object.hash(
        status,
        action,
        order,
        paymentRequest,
        cantDo,
        dispute,
      );

  OrderState copyWith({
    Status? status,
    Action? action,
    Order? order,
    PaymentRequest? paymentRequest,
    CantDo? cantDo,
    Dispute? dispute,
  }) {
    return OrderState(
      status: status ?? this.status,
      action: action ?? this.action,
      order: order ?? this.order,
      paymentRequest: paymentRequest ?? this.paymentRequest,
      cantDo: cantDo ?? this.cantDo,
      dispute: dispute ?? this.dispute,
    );
  }

  OrderState updateFromMostroMessage(MostroMessage message) {
    return copyWith(
      status: message.getPayload<Order>()?.status ?? status,
      action: message.action,
      order: message.getPayload<Order>() ?? order,
      paymentRequest: message.getPayload<PaymentRequest>() ?? paymentRequest,
      cantDo: message.getPayload<CantDo>() ?? cantDo,
      dispute: message.getPayload<Dispute>() ?? dispute,
    );
  }
}
