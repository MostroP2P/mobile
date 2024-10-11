import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_event.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeState.initial()) {
    on<LoadOrders>(_onLoadOrders);
    on<ChangeOrderType>(_onChangeOrderType);
  }

  void _onLoadOrders(LoadOrders event, Emitter<HomeState> emit) {
    emit(state.copyWith(status: HomeStatus.loading));

    // Datos hardcodeados
    final hardcodedOrders = [
      OrderModel(
        user: 'anon',
        rating: '5/5',
        ratingCount: 2,
        timeAgo: '1 week ago',
        amount: '1 200 000',
        currency: 'sats',
        fiatAmount: '31 806',
        fiatCurrency: 'VES',
        premium: '+3%',
        paymentMethod: 'Wire transfer',
        type: 'buy',
        sellerAvatar: 'https://example.com/avatar.jpg', // Placeholder
        sellerName: 'Anon Seller',
        sellerRating: '5',
        sellerReviewCount: 2,
        satsAmount: '1200000',
        exchangeRate: '30000',
        buyerSatsAmount: '1200000',
        buyerFiatAmount: '31806',
      ),
      OrderModel(
        user: 'anon',
        rating: '3/5',
        ratingCount: 5,
        timeAgo: '2 weeks ago',
        amount: '390 000',
        currency: 'sats',
        fiatAmount: '3 231',
        fiatCurrency: 'MXN',
        premium: '+0%',
        paymentMethod: 'Transferencia bancaria',
        type: 'buy',
        sellerAvatar: 'https://example.com/avatar2.jpg', // Placeholder
        sellerName: 'Another Seller',
        sellerRating: '3',
        sellerReviewCount: 5,
        satsAmount: '390000',
        exchangeRate: '29000',
        buyerSatsAmount: '390000',
        buyerFiatAmount: '3231',
      ),
      OrderModel(
        user: 'Pedro9734',
        rating: '5/5',
        ratingCount: 19,
        timeAgo: '2 weeks ago',
        amount: '390 000',
        currency: 'sats',
        fiatAmount: '3 483',
        fiatCurrency: 'MXN',
        premium: '+1%',
        paymentMethod: 'Revolut',
        type: 'buy',
        sellerAvatar: 'https://example.com/avatar3.jpg', // Placeholder
        sellerName: 'Pedro9734',
        sellerRating: '5',
        sellerReviewCount: 19,
        satsAmount: '390000',
        exchangeRate: '31000',
        buyerSatsAmount: '390000',
        buyerFiatAmount: '3483',
      ),
    ];

    emit(state.copyWith(
      status: HomeStatus.loaded,
      allOrders: hardcodedOrders,
      filteredOrders: _filterOrdersByType(hardcodedOrders, state.orderType),
    ));
  }

  void _onChangeOrderType(ChangeOrderType event, Emitter<HomeState> emit) {
    emit(state.copyWith(
      orderType: event.orderType,
      filteredOrders: _filterOrdersByType(state.allOrders, event.orderType),
    ));
  }

  List<OrderModel> _filterOrdersByType(
      List<OrderModel> orders, OrderType type) {
    return orders
        .where((order) =>
            type == OrderType.buy ? order.type == 'buy' : order.type == 'sell')
        .toList();
  }
}
