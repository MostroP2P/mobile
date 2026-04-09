import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/restore/restore_manager.dart';
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
  final hadMasterKey = await keyManager.hasMasterKey();
  await keyManager.init();

  // If master key existed but trade index is not persisted, it means
  // secure storage survived but SharedPreferences was deleted.
  // Sync trade index from Mostro to prevent invalid_trade_index errors.
  if (hadMasterKey && !await keyManager.hasPersistedTradeKeyIndex()) {
    unawaited(ref.read(restoreServiceProvider).syncTradeIndex());
  }

  final mostroNodes = ref.read(mostroNodesProvider.notifier);
  await mostroNodes.init();
  unawaited(mostroNodes.fetchAllNodeMetadata());

  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();
  
  ref.read(subscriptionManagerProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  final settings = ref.read(settingsProvider);
  final expirationHours = settings.sessionExpirationHours ?? Config.sessionExpirationHours;
  final isForever = expirationHours == 0;
  final cutoff = isForever
      ? null
      : DateTime.now().subtract(Duration(hours: expirationHours));

  for (final session in sessionManager.sessions) {
    if(session.orderId == null || (cutoff != null && session.startTime.isBefore(cutoff))) continue;

    ref.read(orderNotifierProvider(session.orderId!).notifier);

    if (session.peer != null) {
      ref.read(chatRoomsProvider(session.orderId!));
    }
  }
});
