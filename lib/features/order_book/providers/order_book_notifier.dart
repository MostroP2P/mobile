import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order_book/notifiers/order_book_notifier.dart';
import 'package:mostro_mobile/features/order_book/notifiers/order_book_state.dart';

final orderBookNotifierProvider = AsyncNotifierProvider<OrderBookNotifier, OrderBookState>(
  OrderBookNotifier.new,
);

