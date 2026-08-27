import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/order/settlement_terms_store.dart';
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

/// The node's fee rate, and when the node published the event carrying it.
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
/// `publishedAt` travels with the rate rather than being read off the event
/// again elsewhere, because it is what separates a term the node supplied
/// after an agreement from one this client was merely late to receive. See
/// [orderFeeRateProvider], which is the only thing that needs the
/// distinction.
///
/// Null when the info event has not arrived, belongs to another node, or does
/// not carry the tag. The getter parses eagerly and throws on a missing tag,
/// which is fine for the About screen it was written for and not for a
/// payment check.
final nodeFeeTermsProvider =
    Provider<({double rate, DateTime? publishedAt})?>((ref) {
  final nodePubkey = ref.watch(
    settingsProvider.select((settings) => settings.mostroPublicKey),
  );
  final info = ref.watch(mostroInfoEventProvider).valueOrNull;
  if (info == null || info.pubkey != nodePubkey) return null;
  try {
    return (rate: info.fee, publishedAt: info.createdAt);
  } catch (e) {
    logger.w('Node info event carries no usable fee rate: $e');
    return null;
  }
});

/// The fee rate the node currently advertises. See [nodeFeeTermsProvider].
///
/// What a commitment pins, and what a session predating pinning follows.
final nodeFeeRateProvider = Provider<double?>(
  (ref) => ref.watch(nodeFeeTermsProvider)?.rate,
);

/// When the trade behind [orderId] committed, from the durable anchor store.
///
/// Deliberately not `Session.startTime`. A restore rebuilds every session with
/// `DateTime.now()`, so that field records when the app last reconstructed the
/// trade rather than when the user agreed to it — and a term the node
/// published after the agreement but before the restore would then read as one
/// that preceded it, which is the substitution pinning exists to refuse. The
/// anchor is written once, before the commitment is published, and a restore
/// does not touch it.
///
/// Null for a session that pinned nothing: one written before pinning existed
/// has no instant of agreement to hold anything to.
final commitmentTimeProvider =
    Provider.family<DateTime?, String>((ref, orderId) {
  final session = ref.watch(sessionProvider(orderId));
  if (session == null || !session.termsPinned) return null;

  return ref
      .read(settlementTermsStoreProvider)
      .termsFor(session.tradeKey.public)
      ?.pinnedAt;
});

/// The fee rate this settlement is held to.
///
/// [nodeFeeRateProvider] tracks whatever the node currently advertises, which
/// it can change under a trade already in flight. This prefers the rate
/// pinned when the session committed, on the same terms as
/// [signedOrderAmountProvider].
///
/// Known race, deliberately not papered over. mostrod computes `order.fee`
/// at take time from `Settings::get_mostro().fee` (`take_sell.rs`,
/// `take_buy.rs`, `util.rs`), while the client pins what the kind-38385 info
/// event advertised. If an operator changes the fee and the republished info
/// event has not reached this client before it takes, the two disagree and
/// the seller meets a hard refusal on an honest trade, recoverable only by
/// cancelling. The window is narrow — it needs a fee change and an
/// unpropagated event at the same moment — but pinning makes the
/// disagreement permanent for that trade, and it is the worst failure mode
/// in this flow.
///
/// Accepting a second figure derived from the live rate would close it, and
/// is not done here: that is exactly the shape of "a term the node supplies
/// after the agreement" that pinning exists to refuse, and it would let a
/// node raise its fee under a trade already committed. If the race shows up
/// in the field, the fix belongs on the daemon side — publishing the fee that
/// applied at take time alongside the order — rather than in a client that
/// guesses which of two rates it is being held to.
final orderFeeRateProvider = Provider.family<double?, String>((ref, orderId) {
  final session = ref.watch(sessionProvider(orderId));

  final pinned = session?.pinnedFeeRate;
  if (pinned != null) return pinned;

  // Pinning ran for this session and came up with no rate. Two unrelated
  // things put a session here, and only one of them is the node's doing:
  //
  //  - the node published no rate at the moment of agreement and supplied
  //    one afterwards. That is not a term of the agreement, and adopting it
  //    is the move pinning exists to stop.
  //  - the node had published one, signed, before the agreement, and this
  //    client had not finished receiving it. Nothing was supplied after the
  //    fact; the client was behind.
  //
  // Refusing both put the second — an ordinary trade on an honest node, over
  // a link slow enough to still be draining the order book — behind a caution
  // for the life of the trade. A warning that fires on honest trades is read
  // once and furniture by the twentieth, which costs more than it buys the
  // one time it fires for the reason it exists.
  //
  // The event's own created_at separates them, and is covered by the
  // signature and the recomputed id, so a node cannot move it without
  // signing for it. It does not hold against one willing to backdate; that
  // case is not blocked today either, only warned about, and a warning that
  // is read beats one that is not.
  //
  // Skew is not compensated. The two sides come from different clocks — the
  // node's for created_at, the device's for the commitment — so a device
  // running behind keeps the caution where an honest node published seconds
  // before the take. That direction is the safe one, and the race this closes
  // is a client draining a backlog, where the event predates the commitment
  // by far more than any plausible skew.
  //
  // None of this can be inferred from a pinned amount being present: a
  // market-price order resolves no sats until after the take, so it pins
  // none, and inferring from that would leave exactly those orders following
  // whatever rate the node publishes next.
  if (session?.termsPinned == true) {
    final committedAt = ref.watch(commitmentTimeProvider(orderId));
    final terms = ref.watch(nodeFeeTermsProvider);
    final publishedAt = terms?.publishedAt;

    // An anchor with no instant behind it, or an event that does not say when
    // it was published, is not evidence that it predates anything.
    if (committedAt == null || terms == null || publishedAt == null) {
      return null;
    }

    return publishedAt.isAfter(committedAt) ? null : terms.rate;
  }

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
