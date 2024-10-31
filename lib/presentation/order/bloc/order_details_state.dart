import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/order_model.dart';

enum OrderDetailsStatus { initial, loading, loaded, error }

class OrderDetailsState extends Equatable {
  final OrderDetailsStatus status;
  final OrderModel? order;
  final String? errorMessage;

  const OrderDetailsState({
    this.status = OrderDetailsStatus.initial,
    this.order,
    this.errorMessage,
  });

  OrderDetailsState copyWith({
    OrderDetailsStatus? status,
    OrderModel? order,
    String? errorMessage,
  }) {
    return OrderDetailsState(
      status: status ?? this.status,
      order: order ?? this.order,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, order, errorMessage];
}
