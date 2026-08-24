import 'dart:async';

import 'package:collection/collection.dart';
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

/// The connected node's kind-38385 info event, followed rather than sampled.
///
/// The repository keeps the event in a mutable field and also emits it on a
/// stream. Reading the field alone caches whatever had arrived at that moment,
/// which is not enough for a consumer built before the event: the info event
/// lands asynchronously after the subscription is opened, and a fee rate read
/// too early would stay missing for the rest of the session.
///
/// Null until the event arrives.
final mostroInfoEventProvider = StreamProvider<NostrEvent?>((ref) {
  final orderRepository = ref.watch(orderRepositoryProvider);

  // Subscribe before sampling the current value. The repository's stream is a
  // broadcast one, so an event fired between the two would be lost, leaving
  // the provider serving a snapshot it has already outlived.
  final controller = StreamController<NostrEvent?>();
  final subscription = orderRepository.mostroInstanceStream.listen(
    controller.add,
    onError: controller.addError,
  );
  controller.add(orderRepository.mostroInstance);

  ref.onDispose(() {
    subscription.cancel();
    controller.close();
  });

  return controller.stream;
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
