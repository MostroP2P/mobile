import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/settlement_amounts.dart';

/// The order amount the node currently publishes for [orderId], in satoshis.
///
/// Read off the kind-38383 order event rather than the direct message that
/// asks for the payment. Both come from the node, but only one of them is the
/// order the user chose: the event is addressable and public, and it is what
/// the take screen showed. A market-price order carries no amount until it is
/// taken, and the node republishes the event with the resolved figure as part
/// of that flow, so by the time either side is asked to act the amount is
/// there.
///
/// Being addressable cuts both ways: the node can republish it again at any
/// point, which is why a settlement is held to [signedOrderAmountProvider]
/// and not to this.
///
/// Null when no event has arrived, or when it carries no usable amount.
final publishedOrderAmountProvider =
    Provider.family<int?, String>((ref, orderId) {
  final event = ref.watch(eventProvider(orderId));
  if (event == null) return null;

  final amount = int.tryParse(event.amount ?? '');
  if (amount == null || amount <= 0) return null;
  return amount;
});

/// The order amount this settlement is held to, in satoshis.
///
/// The figure pinned when the session committed to the trade, so republishing
/// the order event afterwards cannot move what the client will accept. Falls
/// back to the live event where nothing was pinned: sessions written before
/// the pin existed, and market-price and range orders, whose sats figure the
/// node only resolves after the commitment there was to make.
final signedOrderAmountProvider = Provider.family<int?, String>((ref, orderId) {
  final pinned = ref.watch(sessionProvider(orderId))?.pinnedAmountSats;
  if (pinned != null) return pinned;

  return ref.watch(publishedOrderAmountProvider(orderId));
});

/// The node's fee rate, from its kind-38385 info event.
///
/// Followed rather than sampled: the info event arrives asynchronously after
/// the order subscription is opened, so a screen built first would otherwise
/// hold a null read for the rest of the session and keep falling back to the
/// weaker check.
///
/// The event is pinned to the node currently selected. Switching instances
/// clears the repository's cached event without emitting the drop, so an
/// unpinned fee rate would go on deriving amounts from the previous node's
/// terms and refuse settlements that are in fact correct.
///
/// Null when the info event has not arrived, belongs to another node, or does
/// not carry the tag. The getter parses eagerly and throws on a missing tag,
/// which is fine for the About screen it was written for and not for a
/// payment check.
final nodeFeeRateProvider = Provider<double?>((ref) {
  final nodePubkey = ref.watch(
    settingsProvider.select((settings) => settings.mostroPublicKey),
  );
  final info = ref.watch(mostroInfoEventProvider).valueOrNull;
  if (info == null || info.pubkey != nodePubkey) return null;
  try {
    return info.fee;
  } catch (e) {
    logger.w('Node info event carries no usable fee rate: $e');
    return null;
  }
});

/// The fee rate this settlement is held to.
///
/// [nodeFeeRateProvider] tracks whatever the node currently advertises, which
/// it can change under a trade already in flight. This prefers the rate
/// pinned when the session committed, on the same terms as
/// [signedOrderAmountProvider].
final orderFeeRateProvider = Provider.family<double?, String>((ref, orderId) {
  final session = ref.watch(sessionProvider(orderId));

  final pinned = session?.pinnedFeeRate;
  if (pinned != null) return pinned;

  // A session holding an amount but no rate is one that committed while the
  // info event was still missing: pinning ran, and there was nothing to pin.
  // Reading the live rate here would let the node publish the term after the
  // fact, which is the whole of what pinning exists to prevent. Report it
  // unknown instead and let the screen say the check could not be made.
  if (session?.pinnedAmountSats != null) return null;

  return ref.watch(nodeFeeRateProvider);
});

/// What the seller's hold invoice for [orderId] should ask for, derived from
/// the signed order amount and the signed fee rate.
///
/// Null when either input is missing. A caller that gets null has not learned
/// that the payment is wrong — only that it cannot re-derive what it should
/// be, and should fall back to the weaker check it can still make.
final anchoredSellerAmountProvider =
    Provider.family<int?, String>((ref, orderId) {
  final amountSats = ref.watch(signedOrderAmountProvider(orderId));
  final feeRate = ref.watch(orderFeeRateProvider(orderId));
  if (amountSats == null || feeRate == null) return null;

  return SettlementAmounts.sellerPays(
    amountSats: amountSats,
    feeRate: feeRate,
  );
});

/// What the buyer's payout invoice for [orderId] should ask for, derived from
/// the signed order amount and the signed fee rate.
///
/// The figure is the order amount less the buyer's half of the fee, so it is
/// never the amount shown on the order — a client comparing against that
/// would refuse every correct payout.
///
/// Null on the same terms as [anchoredSellerAmountProvider]: the caller has
/// learned nothing about whether the request is right, only that it cannot
/// re-derive what it should be.
final anchoredBuyerAmountProvider =
    Provider.family<int?, String>((ref, orderId) {
  final amountSats = ref.watch(signedOrderAmountProvider(orderId));
  final feeRate = ref.watch(orderFeeRateProvider(orderId));
  if (amountSats == null || feeRate == null) return null;

  return SettlementAmounts.buyerReceives(
    amountSats: amountSats,
    feeRate: feeRate,
  );
});
