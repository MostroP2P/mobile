import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/notifiers/open_orders_notifier.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/shared/notifiers/notification_notifier.dart';
import 'package:mostro_mobile/notifiers/open_orders_repository_notifier.dart';
import 'package:mostro_mobile/services/mostro_service.dart';
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
const orderFilterDurationHours = 48;

final orderEventsProvider = StreamProvider<List<NostrEvent>>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);
  orderRepository.subscribeToOrders();

  return orderRepository.eventsStream;
});


final openOrdersNotifierProvider =
    StateNotifierProvider<OpenOrdersNotifier, List<NostrEvent>>(
  (ref) => OpenOrdersNotifier(ref.watch(nostrServicerProvider)),
);

final openOrdersRepositoryProvider =
    AsyncNotifierProvider<OpenOrdersRepositoryNotifier, OpenOrdersRepository>(
  OpenOrdersRepositoryNotifier.new,
);

final sessionManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.watch(sessionManagerProvider);
  final nostrService = ref.watch(nostrServicerProvider);
  return MostroService(nostrService, sessionStorage);
});

final mostrorRepositoryProvider = Provider<MostroRepository>((ref) {
  final mostroService = ref.watch(mostroServiceProvider);
  final openOrdersRepository = ref.watch(openOrdersRepositoryProvider).value;
  return MostroRepository(mostroService, openOrdersRepository!);
});
