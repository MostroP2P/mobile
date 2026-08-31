import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

final orderRepositoryProvider = Provider((ref) {
  final nostrService = ref.read(nostrServiceProvider);
  final settings = ref.read(settingsProvider);
  final orderRepo = OpenOrdersRepository(nostrService, settings);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    orderRepo.updateSettings(next);
  });

  return orderRepo;
});

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.read(orderRepositoryProvider);
  return orderRepository.eventsStream;
});

/// The book indexed by order id, rebuilt once per emission. Family lookups
/// go through this map instead of each scanning the whole list.
final orderMapProvider = Provider<Map<String, NostrEvent>>((ref) {
  final allEvents = ref.watch(orderEventsProvider).maybeWhen(
        data: (data) => data,
        orElse: () => const <NostrEvent>[],
      );
  return {
    for (final event in allEvents)
      if (event.orderId != null) event.orderId!: event,
  };
});

final eventProvider = Provider.family<NostrEvent?, String>((ref, orderId) {
  // O(1) per lookup; previously a lastWhereOrNull scan of the whole book per
  // family instance per emission (O(sessions x orders) per public event).
  return ref.watch(orderMapProvider.select((map) => map[orderId]));
});
