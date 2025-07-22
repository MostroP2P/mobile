import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';

class Subscription {
  final NostrRequest request;
  final StreamSubscription<NostrEvent> streamSubscription;
  final Function() onCancel;

  Subscription({
    required this.request,
    required this.streamSubscription,
    required this.onCancel,
  });

  void cancel(  ) {
    streamSubscription.cancel();
    onCancel();
  }

  Subscription copyWith({
    NostrRequest? request,
    StreamSubscription<NostrEvent>? streamSubscription,
    Function()? onCancel,
  }) {
    return Subscription(
      request: request ?? this.request,
      streamSubscription: streamSubscription ?? this.streamSubscription,
      onCancel: onCancel ?? this.onCancel,
    );
  }

  @override
  String toString() {
    return 'Subscription(request: $request, streamSubscription: $streamSubscription)';
  }
}
