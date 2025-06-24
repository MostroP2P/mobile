import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/subscription_manager.dart';

final subscriptionManagerProvider =
    Provider<SubscriptionManager>(
  (ref) => SubscriptionManager(ref),
);
