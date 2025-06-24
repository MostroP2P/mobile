import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class SubscriptionManager {
  final Ref ref;
  final Map<SubscriptionType, Subscription> subscriptions = {};

  SubscriptionManager(this.ref);

  Stream<NostrEvent> subscribe(SubscriptionType type, NostrFilter filter) {
    // Cancel any existing subscription
    subscriptions[type]?.cancel();

    // Create a new subscription
    final nostrService = ref.read(nostrServiceProvider);
    final controller = StreamController<NostrEvent>();

    // Update the state with the new filter
    final newRequest = NostrRequest(filters: [filter]);

    // Start listening to events
    subscriptions[type] = Subscription(
      id: type.toString(),
      request: newRequest,
      streamSubscription: nostrService.subscribeToEvents(newRequest).listen(
            controller.add,
            onError: controller.addError,
            onDone: controller.close,
            cancelOnError: false,
          ),
    );

    return controller.stream;
  }

  void unsubscribe(SubscriptionType type) {
    subscriptions[type]?.cancel();
    subscriptions.remove(type);
  }
}

enum SubscriptionType {
  chat,
  trades,
  orders,
}

class Subscription {
  final String id;
  final NostrRequest request;
  final StreamSubscription<NostrEvent> streamSubscription;

  Subscription({
    required this.id,
    required this.request,
    required this.streamSubscription,
  });

  void cancel() {
    streamSubscription.cancel();
  }

  Subscription copyWith({
    NostrRequest? request,
    StreamSubscription<NostrEvent>? streamSubscription,
  }) {
    return Subscription(
      id: id,
      request: request ?? this.request,
      streamSubscription: streamSubscription ?? this.streamSubscription,
    );
  }
}
