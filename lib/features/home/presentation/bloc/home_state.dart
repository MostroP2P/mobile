import 'package:equatable/equatable.dart';
import 'package:mostro_mobile/features/home/data/models/order_model.dart';

enum HomeStatus { initial, loading, loaded, error }

enum OrderType { buy, sell }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<OrderModel> allOrders;
  final List<OrderModel> filteredOrders;
  final OrderType orderType;

  const HomeState({
    required this.status,
    required this.allOrders,
    required this.filteredOrders,
    required this.orderType,
  });

  factory HomeState.initial() {
    return const HomeState(
      status: HomeStatus.initial,
      allOrders: [],
      filteredOrders: [],
      orderType: OrderType.buy,
    );
  }

  HomeState copyWith({
    HomeStatus? status,
    List<OrderModel>? allOrders,
    List<OrderModel>? filteredOrders,
    OrderType? orderType,
  }) {
    return HomeState(
      status: status ?? this.status,
      allOrders: allOrders ?? this.allOrders,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      orderType: orderType ?? this.orderType,
    );
  }

  @override
  List<Object> get props => [status, allOrders, filteredOrders, orderType];
}
