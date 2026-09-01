import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/features/mostro/mostro_nodes_provider.dart';
import 'package:mostro_mobile/features/order/providers/order_notifier_provider.dart';
import 'package:mostro_mobile/features/relays/relay_health_monitor.dart';
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

  // Start the relay health watchdog: re-engages bootstrap relays and
  // re-subscribes if no relay is alive (cold start or all discovered down).
  ref.read(relayHealthMonitorProvider);

  ref.listen<Settings>(settingsProvider, (previous, next) {
    ref.read(backgroundServiceProvider).updateSettings(next);
  });

  final settings = ref.read(settingsProvider);
  final expirationHours =
      settings.sessionExpirationHours ?? Config.sessionExpirationHours;
  final isForever = expirationHours == 0;
  final cutoff = isForever
      ? null
      : DateTime.now().subtract(Duration(hours: expirationHours));

  final messageStorage = ref.read(mostroStorageProvider);
  for (final session in sessionManager.sessions) {
    if (session.orderId == null ||
        (cutoff != null && session.startTime.isBefore(cutoff))) {
      continue;
    }

    // Settled orders initialize lazily when a screen watches them: an eager
    // notifier per finished trade meant a storage watcher and a book listener
    // alive until process exit.
    final latest = await messageStorage.getLatestMessageById(session.orderId!);
    if (!isSettledOrderMessage(latest)) {
      ref.read(orderNotifierProvider(session.orderId!).notifier);
    }

    // The chat notifier stays eager regardless: it is the only consumer of
    // SubscriptionManager.chat, a broadcast stream that drops events while
    // nobody listens, so a peer message on a finished trade would be lost
    // until the user happened to open the Chats tab.
    if (session.peer != null) {
      ref.read(chatRoomsProvider(session.orderId!));
    }
  }
});

/// How long after the last message a finished order still initializes
/// eagerly, so trailing notices (`bond-slashed`, ratings) are reacted to
/// live rather than only persisted.
const Duration settledOrderGrace = Duration(hours: 24);

/// Statuses after which Mostro sends nothing that needs a live reaction.
///
/// Deliberately *not* [Status.isTerminal], which answers a different
/// question — whether a session can be deleted during cleanup — and is only
/// ever applied to sessions already past the expiration cutoff. Three of its
/// members still expect traffic and stay eager here:
///   * [Status.settledHoldInvoice] — the window between release and payout,
///     where the buyer may still replace a wrong invoice;
///   * [Status.canceled] — carries the deferred session deletion that
///     `OrderNotifier.sync()` re-arms via `reconcileCanceledBondedSession()`,
///     plus a trailing `bond-slashed` notice;
///   * [Status.success] — the rating exchange, which has no time bound.
const Set<Status> settledOrderStatuses = {
  Status.canceledByAdmin,
  Status.settledByAdmin,
  Status.completedByAdmin,
  Status.cooperativelyCanceled,
  Status.expired,
};

/// Whether the order's last stored message reports a settled status old
/// enough that nothing further is expected. A missing message, a non-order
/// payload, an unknown timestamp or a recent one all count as live, so
/// anything ambiguous keeps today's eager behaviour.
bool isSettledOrderMessage(MostroMessage? message, {DateTime? now}) {
  final order = message?.getPayload<Order>();
  if (order == null || !settledOrderStatuses.contains(order.status)) {
    return false;
  }
  final at = _messageTime(message!.timestamp);
  if (at == null) return false;
  return (now ?? DateTime.now()).difference(at) > settledOrderGrace;
}

/// The daemon sends seconds, the app fills in milliseconds when the field is
/// absent, and both units coexist in the store.
DateTime? _messageTime(int? raw) {
  if (raw == null || raw <= 0) return null;
  final ms = raw < 1000000000000 ? raw * 1000 : raw;
  return DateTime.fromMillisecondsSinceEpoch(ms);
}
