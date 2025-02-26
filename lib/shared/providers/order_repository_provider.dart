import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

final orderRepositoryProvider = Provider((ref) {
  final nostrService = ref.read(nostrServiceProvider);
  final settings = ref.watch(settingsProvider);
  final orderRepo = OpenOrdersRepository(nostrService, settings);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    orderRepo.updateSettings(next);
  });

  return orderRepo;
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
