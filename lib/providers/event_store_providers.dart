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

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  DateTime filterTime = DateTime.now().subtract(Duration(hours: 24));
  var filter = NostrFilter(
    kinds: const [38383],
    since: filterTime,
  );
  orderRepository.subscribe(filter);

  return orderRepository.eventsStream;
});
