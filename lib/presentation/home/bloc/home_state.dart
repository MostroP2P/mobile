import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';

class HomeState {
  final OrderType orderType;
  final List<NostrEvent> filteredOrders;

  HomeState({required this.orderType, required this.filteredOrders});

  HomeState copyWith({
    OrderType? orderType,
    List<NostrEvent>? filteredOrders,
  }) {
    return HomeState(
      orderType: orderType ?? this.orderType,
      filteredOrders: filteredOrders ?? this.filteredOrders,
    );
  }
}
