import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';

class HomeState {
  final OrderType orderType;
  final List<NostrEvent> filteredOrders;
  final bool isLoading;
  final String? error;

  HomeState({
    required this.orderType,
    required this.filteredOrders,
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    OrderType? orderType,
    List<NostrEvent>? filteredOrders,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      orderType: orderType ?? this.orderType,
      filteredOrders: filteredOrders ?? this.filteredOrders,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}
