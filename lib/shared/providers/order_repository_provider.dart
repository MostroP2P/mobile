import 'package:collection/collection.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/services/connection_manager.dart';

final orderRepositoryProvider = Provider((ref) {
  final nostrService = ref.read(nostrServiceProvider);
  final connectionManager = ref.read(connectionManagerInstanceProvider);
  final settings = ref.read(settingsProvider);
  final orderRepo = OpenOrdersRepository(nostrService, connectionManager, settings);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    orderRepo.updateSettings(next);
  });

  return orderRepo;
});

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.read(orderRepositoryProvider);
  return orderRepository.eventsStream;
});

final eventProvider = Provider.family<NostrEvent?, String>((ref, orderId) {
  final allEventsAsync = ref.watch(orderEventsProvider);
  final allEvents = allEventsAsync.maybeWhen(
    data: (data) => data,
    orElse: () => [],
  );
  // lastWhereOrNull returns null if no match is found
  return allEvents
      .lastWhereOrNull((evt) => (evt as NostrEvent).orderId == orderId);
});
