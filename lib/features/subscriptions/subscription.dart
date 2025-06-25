import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';

class Subscription {
  final NostrRequest request;
  final StreamSubscription<NostrEvent> streamSubscription;

  Subscription({
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
      request: request ?? this.request,
      streamSubscription: streamSubscription ?? this.streamSubscription,
    );
  }
}
