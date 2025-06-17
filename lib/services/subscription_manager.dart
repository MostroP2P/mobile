import 'dart:async';

import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class SubscriptionManager extends StateNotifier<Subscription> {
  final Ref ref;
  StreamSubscription<NostrEvent>? _subscription;

  SubscriptionManager(this.ref) : super(
    Subscription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      request: NostrRequest(filters: []),
    ),
  );

  Stream<NostrEvent> subscribe(NostrFilter filter) {
    // Cancel any existing subscription
    _subscription?.cancel();
    
    // Create a new subscription
    final nostrService = ref.read(nostrServiceProvider);
    final controller = StreamController<NostrEvent>();
    
    // Update the state with the new filter
    final newRequest = NostrRequest(filters: [filter]);
    state = state.copyWith(request: newRequest);
    
    // Start listening to events
    _subscription = nostrService.subscribeToEvents(newRequest).listen(
      controller.add,
      onError: controller.addError,
      onDone: controller.close,
      cancelOnError: false,
    );
    
    return controller.stream;
  }

  void unsubscribe() {
    _subscription?.cancel();
    state = state.copyWith(request: NostrRequest(filters: []));
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class Subscription {
  final String id;
  final NostrRequest request;

  Subscription({required this.id, required this.request});

  Subscription copyWith({NostrRequest? request}) {
    return Subscription(
      id: id,
      request: request ?? this.request,
    );
  }
}