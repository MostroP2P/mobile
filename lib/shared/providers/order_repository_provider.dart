import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

final orderRepositoryProvider = Provider((ref) {
  final nostrService = ref.read(nostrServiceProvider);
  return OpenOrdersRepository(nostrService);
});

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  orderRepository.subscribeToOrders();

  return orderRepository.eventsStream;
});

final eventProvider =
    FutureProvider.family<NostrEvent?, String>((ref, orderId) {
  final repository = ref.watch(orderRepositoryProvider);
  return repository.getOrderById(orderId);
});
