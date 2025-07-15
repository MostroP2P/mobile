import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/settings/settings.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/notifiers/order_action_notifier.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_service_provider.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';

final appInitializerProvider = FutureProvider<void>((ref) async {
  final nostrService = ref.read(nostrServiceProvider);
  await nostrService.init(ref.read(settingsProvider));

  final keyManager = ref.read(keyManagerProvider);
  await keyManager.init();

  final sessionManager = ref.read(sessionNotifierProvider.notifier);
  await sessionManager.init();

  // --- Custom logic for initializing notifiers and chats ---
  final now = DateTime.now();
  final cutoff = now.subtract(const Duration(hours: 24));
  final sessions = sessionManager.sessions;
  final messageStorage = ref.read(mostroStorageProvider);
  final terminalStatuses = {
    Status.canceled,
    Status.cooperativelyCanceled,
    Status.success,
    Status.expired,
    Status.canceledByAdmin,
    Status.settledByAdmin,
    Status.completedByAdmin,
  };
  for (final session in sessions) {
    if (session.startTime.isAfter(cutoff)) {
      bool isActive = true;
      if (session.orderId != null) {
        final latestOrderMsg = await messageStorage
            .getLatestMessageOfTypeById<Order>(session.orderId!);
        final status = latestOrderMsg?.payload is Order
            ? (latestOrderMsg!.payload as Order).status
            : null;
        if (status != null && terminalStatuses.contains(status)) {
          isActive = false;
        }
      }
      if (isActive) {
        // Initialize order notifier if needed
        ref.read(orderNotifierProvider(session.orderId!).notifier);
        // Initialize chat notifier if needed
        if (session.peer != null) {
          ref.read(chatRoomsProvider(session.orderId!).notifier);
        }
      }
    }
  }

  final mostroService = ref.read(mostroServiceProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    sessionManager.updateSettings(next);
    mostroService.updateSettings(next);
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  final mostroStorage = ref.read(mostroStorageProvider);

  for (final session in sessionManager.sessions) {
    if (session.orderId != null) {
      final order = await mostroStorage.getLatestMessageById(session.orderId!);
      if (order != null) {
        // Set the order action
        ref.read(orderActionNotifierProvider(session.orderId!).notifier).set(
              order.action,
            );

        // Explicitly initialize order notifier
        // to ensure it's all properly set up for this orderId
        ref.read(orderNotifierProvider(session.orderId!).notifier).sync();
      }

      // Read the order notifier provider last, which will watch all the above
      ref.read(orderNotifierProvider(session.orderId!));
    }

    if (session.peer != null) {
      final chat = ref.read(
        chatRoomsProvider(session.orderId!).notifier,
      );
      chat.subscribe();
    }
  }
});
