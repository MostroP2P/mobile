import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

final nostrServicerProvider = Provider<NostrService>((ref) {
  return NostrService()..init();
});

final orderRepositoryProvider = Provider((ref) {
  final nostrService = ref.read(nostrServicerProvider);
  return OpenOrdersRepository(nostrService);
});

/// Event kind 38383 represents order events in the Nostr protocol as per NIP-69
const orderEventKind = 38383;
const orderFilterDurationHours = 24;

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  DateTime filterTime = DateTime.now().subtract(Duration(hours: orderFilterDurationHours));
  var filter = NostrFilter(
    kinds: const [orderEventKind],
    since: filterTime,
  );
  orderRepository.subscribe(filter);

  return orderRepository.eventsStream;
});