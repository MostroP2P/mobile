import 'package:equatable/equatable.dart';
import '../../data/models/order_model.dart';
import 'home_event.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<OrderModel> orders;
  final OrderType orderType;

  const HomeState({
    this.status = HomeStatus.initial,
    this.orders = const [],
    this.orderType = OrderType.buy,
  });

  HomeState copyWith({
    HomeStatus? status,
    List<OrderModel>? orders,
    OrderType? orderType,
  }) {
    return HomeState(
      status: status ?? this.status,
      orders: orders ?? this.orders,
      orderType: orderType ?? this.orderType,
    );
  }

  List<OrderModel> get filteredOrders {
    return orders
        .where((order) =>
            order.type == (orderType == OrderType.buy ? 'buy' : 'sell'))
        .toList();
  }

  @override
  List<Object> get props => [status, orders, orderType];
}
