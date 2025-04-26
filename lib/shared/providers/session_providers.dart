import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/features/order/notfiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/cant_do_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/payment_request_notifier.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/session_storage_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

class SessionProviders {
  final String orderId;
  final OrderNotifier orderNotifier;
  final PaymentRequestNotifier paymentRequestNotifier;
  final CantDoNotifier cantDoNotifier;

  SessionProviders({
    required this.orderId,
    required Ref ref,
  })  : orderNotifier = OrderNotifier(orderId, ref),
        paymentRequestNotifier = PaymentRequestNotifier(orderId, ref),
        cantDoNotifier = CantDoNotifier(orderId, ref);

  void dispose() {
    orderNotifier.dispose();
    paymentRequestNotifier.dispose();
    cantDoNotifier.dispose();
  }
}

@riverpod
SessionProviders sessionProviders(Ref ref, String orderId) {
  final providers = SessionProviders(orderId: orderId, ref: ref);
  ref.onDispose(providers.dispose);
  return providers;
}

/// Stream provider for watching both session and message state together
@riverpod
Stream<SessionWithMessages> sessionWithMessages(Ref ref, String orderId) {
  // Create a StreamController to emit combined data
  final controller = StreamController<SessionWithMessages>();
  
  // Get both streams
  final sessionStream = ref.watch(sessionProvider(orderId).stream);
  final messagesStream = ref.watch(mostroMessageHistoryProvider(orderId).stream);
  
  // Track latest values
  Session? latestSession;
  List<MostroMessage> latestMessages = [];
  
  // Subscribe to both streams
  final sessionSubscription = sessionStream.listen((session) {
    latestSession = session;
    controller.add(SessionWithMessages(
      session: latestSession,
      messages: latestMessages,
    ));
  });
  
  final messagesSubscription = messagesStream.listen((messages) {
    latestMessages = messages;
    controller.add(SessionWithMessages(
      session: latestSession,
      messages: latestMessages,
    ));
  });
  
  // Clean up subscriptions when the stream is closed
  ref.onDispose(() {
    sessionSubscription.cancel();
    messagesSubscription.cancel();
    controller.close();
  });
  
  return controller.stream;
}

/// A combined class for session and its messages
class SessionWithMessages {
  final Session? session;
  final List<MostroMessage> messages;
  
  SessionWithMessages({this.session, required this.messages});
  
  bool get hasSession => session != null;
  bool get hasMessages => messages.isNotEmpty;
  MostroMessage? get latestMessage => messages.isNotEmpty ? messages.first : null;
}

