import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';

enum AddOrderStatus { initial, loading, success, submitting, submitted, failure }

class AddOrderState extends Equatable {
  final OrderType currentType;
  final AddOrderStatus status;
  final String? errorMessage;
  final String? currency;

  const AddOrderState({
    this.currentType = OrderType.sell,
    this.status = AddOrderStatus.initial,
    this.errorMessage,
    this.currency,
  });

  AddOrderState copyWith({
    OrderType? currentType,
    AddOrderStatus? status,
    String? errorMessage,
  }) {
    return AddOrderState(
      currentType: currentType ?? this.currentType,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [currentType, status, errorMessage, currency];
}
