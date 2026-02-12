import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/features/subscriptions/subscription_manager_provider.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init(ref.read(settingsProvider));

  final keyManager = ref.read(keyManagerProvider);
  await keyManager.init();

  final mostroNodes = ref.read(mostroNodesProvider.notifier);
  await mostroNodes.init();
  unawaited(mostroNodes.fetchAllNodeMetadata());

  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();
  
  ref.read(subscriptionManagerProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  final cutoff = DateTime.now().subtract(const Duration(hours: Config.sessionExpirationHours));

  for (final session in sessionManager.sessions) {
    if(session.orderId == null || session.startTime.isBefore(cutoff)) continue;

    ref.read(orderNotifierProvider(session.orderId!).notifier);

    if (session.peer != null) {
      ref.read(chatRoomsProvider(session.orderId!).notifier).subscribe();
    }
  }
});
