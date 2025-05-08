import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/order/notfiers/order_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/cant_do_notifier.dart';
import 'package:mostro_mobile/features/order/notfiers/payment_request_notifier.dart';
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
  //ref.onDispose(providers.dispose);
  return providers;
}

