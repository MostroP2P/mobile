import 'package:equatable/equatable.dart';
import '../../../../data/models/order_model.dart';

class HomeState extends Equatable {
  final List<OrderModel> orders;
  final bool isLoading;
  final String? error;
  final bool isBuySelected;
  final OrderModel? selectedOrder;

  const HomeState({
    required this.orders,
    required this.isLoading,
    this.error,
    required this.isBuySelected,
    this.selectedOrder,
  });

  factory HomeState.initial() {
    return const HomeState(
      orders: [],
      isLoading: false,
      isBuySelected: true,
    );
  }

  HomeState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    String? error,
    bool? isBuySelected,
    OrderModel? selectedOrder,
  }) {
    return HomeState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      isBuySelected: isBuySelected ?? this.isBuySelected,
      selectedOrder: selectedOrder ?? this.selectedOrder,
    );
  }

  @override
  List<Object?> get props =>
      [orders, isLoading, error, isBuySelected, selectedOrder];
}
