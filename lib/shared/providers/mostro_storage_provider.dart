import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

final mostroStorageProvider = Provider<MostroStorage>((ref) {
  final mostroDatabase = ref.watch(mostroDatabaseProvider);
  return MostroStorage(db: mostroDatabase);
});

final mostroMessageStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestMessage(orderId);
});

final mostroMessageHistoryProvider =
    StreamProvider.family<List<MostroMessage>, String>(
  (ref, orderId) {
    final storage = ref.read(mostroStorageProvider);
    return storage.watchAllMessages(orderId);
  },
);

final mostroOrderStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestMessageOfType<Order>(orderId);
});

/// Whether [action]'s Order payload states the *payout* amount.
///
/// Several actions carry an Order and their `amount` does not mean the same
/// thing: `orders` — the restore reply — carries the order's gross, and
/// `buyer-took-order` and `pay-invoice` carry what the seller locks. Only the
/// payout request and its confirmation state what the buyer's invoice must be
/// worth, which is the gross minus the Mostro fee.
bool statesPayoutAmount(Action action) =>
    action == Action.addInvoice || action == Action.holdInvoicePaymentAccepted;

/// Newest message in [history] that states the payout amount, or null.
///
/// [history] arrives newest first. Returns null rather than falling back to
/// another Order payload: the node rejects any invoice that is not worth
/// exactly the payout amount, so a wrong figure traps the user in a loop of
/// rejections with nothing on screen to explain it (#748).
MostroMessage? latestPayoutMessage(List<MostroMessage> history) {
  for (final message in history) {
    if (!statesPayoutAmount(message.action)) continue;
    if (message.getPayload<Order>() != null) return message;
  }
  return null;
}

/// Latest message stating the payout amount for [orderId].
///
/// The payout screen reads this instead of [mostroOrderStreamProvider], which
/// emits whatever Order payload is newest and therefore starts reporting the
/// gross as soon as a restore lands.
final payoutOrderStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchAllMessages(orderId).map(latestPayoutMessage);
});
