import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_repository.dart';
import 'package:mostro_mobile/data/repositories/open_orders_notifier.dart';
import 'package:mostro_mobile/data/repositories/open_orders_repository.dart';
import 'package:mostro_mobile/data/repositories/secure_storage_manager.dart';
import 'package:mostro_mobile/notifiers/global_notification_notifier.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_notifier.dart';
import 'package:mostro_mobile/presentation/add_order/bloc/add_order_state.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_notifier.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_state.dart';
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
  DateTime filterTime =
      DateTime.now().subtract(Duration(hours: orderFilterDurationHours));
  var filter = NostrFilter(
    kinds: const [orderEventKind],
    since: filterTime,
  );
  orderRepository.subscribeToOrders(filter);

  return orderRepository.eventsStream;
});

final addOrderNotifierProvider =
    StateNotifierProvider<AddOrderNotifier, AddOrderState>((ref) {
  final mostroService = ref.watch(mostroServiceProvider);
  return AddOrderNotifier(mostroService);
});

final globalNotificationProvider =
    StateNotifierProvider<GlobalNotificationNotifier, NotificationMessage?>(
        (ref) => GlobalNotificationNotifier());

final openOrdersNotifierProvider =
    StateNotifierProvider<OpenOrdersNotifier, List<NostrEvent>>(
  (ref) => OpenOrdersNotifier(ref.watch(nostrServicerProvider)),
);

final homeNotifierProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (ref) {
    final openOrdersNotifier = ref.read(orderEventsProvider);
    return HomeNotifier(openOrdersNotifier);
  },
);

final sessionManagerProvider = Provider<SecureStorageManager>((ref) {
  return SecureStorageManager();
});

final mostrorRepositoryProvider = Provider<MostroRepository>((ref) {
  final nostrService = ref.watch(nostrServicerProvider);
  return MostroRepository(nostrService);
});

final mostroServiceProvider = Provider<MostroService>((ref) {
  final sessionStorage = ref.watch(sessionManagerProvider);
  final nostrService = ref.watch(nostrServicerProvider);
  final mostroRepository = ref.watch(mostrorRepositoryProvider);
  return MostroService(nostrService, sessionStorage, mostroRepository, ref);
});
