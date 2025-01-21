import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order_book/notifiers/order_book_state.dart';

class OrderBookNotifier extends AsyncNotifier<OrderBookState> {
  @override
  FutureOr<OrderBookState> build() async {
    state = const AsyncLoading();

    return OrderBookState([]);

  }
  
}