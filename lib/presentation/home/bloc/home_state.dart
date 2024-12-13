import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/order_model.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<OrderModel> allOrders;
  final List<OrderModel> filteredOrders;
  final OrderType orderType;
  final String errorMessage;

  const HomeState({
    required this.status,
    required this.allOrders,
    required this.filteredOrders,
    required this.orderType,
    required this.errorMessage,
  });

  factory HomeState.initial() {
    return const HomeState(
      status: HomeStatus.initial,
      allOrders: [],
      filteredOrders: [],
      orderType: OrderType.buy,
      errorMessage: "",
    );
  }

  HomeState copyWith({
    HomeStatus? status,
    List<OrderModel>? allOrders,
    List<OrderModel>? filteredOrders,
    OrderType? orderType,
    String? errorMessage,
  }) {
    return HomeState(
      status: status ?? this.status,
      allOrders: allOrders ?? this.allOrders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      orderType: orderType ?? this.orderType,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object> get props =>
      [status, allOrders, filteredOrders, orderType, errorMessage];
}
