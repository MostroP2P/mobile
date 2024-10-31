import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

enum AddOrderStatus { initial, loading, success, failure }

class AddOrderState extends Equatable {
  final OrderType currentType;
  final AddOrderStatus status;
  final String? errorMessage;

  const AddOrderState({
    this.currentType = OrderType.sell,
    this.status = AddOrderStatus.initial,
    this.errorMessage,
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
  List<Object?> get props => [currentType, status, errorMessage];
}