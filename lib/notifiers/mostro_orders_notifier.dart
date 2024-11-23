import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';

class MostroOrdersNotifier extends StateNotifier<List<Order>> {
  final MostroRepository _repository;

  MostroOrdersNotifier(this._repository) : super([]) {
    _repository.ordersStream.listen((orders) {
      state = orders;
    });
  }

  Future<void> cleanupExpiredOrders(DateTime now) async {
    _repository.cleanupExpiredOrders(now);
    state = await _repository.ordersStream.first;
  }
}
