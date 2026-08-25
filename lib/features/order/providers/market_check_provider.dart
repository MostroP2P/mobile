import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/yadio_exchange_service.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

/// How long a fetched rate may be reused before it is asked for again.
///
/// Bitcoin moves, and a settlement checked against a price from hours ago is
/// not checked against the market. Short enough that a rate cannot outlive
/// the screen it was fetched for by much, long enough that a rebuild does not
/// mean another request.
const Duration kQuoteTtl = Duration(minutes: 2);

/// A bitcoin price from a source the connected node does not control.
///
/// Deliberately not [exchangeServiceProvider], which asks the node first: it
/// reads the node's own kind-30078 rates event and only falls back to Yadio if
/// that fails. That is the right order for pricing an order the user is
/// composing, and the wrong one for checking the node's arithmetic — a node
/// that skims a settlement can publish the rate that makes the skim look
/// correct.
final independentExchangeServiceProvider = Provider<ExchangeService>(
  (ref) => YadioExchangeService(),
);

/// Fiat units per bitcoin for [fiatCode], from the independent source.
///
/// Null rather than an error when the rate cannot be had: being offline is not
/// evidence against a settlement, and the caller reports it as a check it
/// could not make rather than as a settlement that passed.
///
/// Disposed with its last listener and refetched on a [kQuoteTtl] timer. Held
/// alive for the process, as a plain family is, the first rate fetched would
/// go on pricing every later trade — a settlement hours later would be
/// compared against a price from the first screen that ever asked.
final independentFiatPerBtcProvider =
    FutureProvider.autoDispose.family<double?, String>((ref, fiatCode) async {
  if (fiatCode.isEmpty) return null;

  final staleAt = Timer(kQuoteTtl, ref.invalidateSelf);
  ref.onDispose(staleAt.cancel);

  try {
    final service = ref.watch(independentExchangeServiceProvider);
    return await service.getExchangeRate(fiatCode, 'BTC');
  } catch (e) {
    logger.w('Independent rate for $fiatCode unavailable: $e');
    return null;
  }
});

/// Re-prices [orderId] against the independent rate.
///
/// Only applies where the client holds no figure of its own. A session that
/// pinned the sats amount at commitment is already held to what the user saw
/// on the take screen, and re-pricing it would only second-guess a number
/// they accepted with their eyes open: a fixed-amount order may sit off the
/// market on purpose. What is left is the market-price and range orders,
/// whose sats the node resolved after the commitment.
///
/// Sessions written before pinning existed are left out. They pinned no sats
/// either, so without this they would all fall through to the check — and a
/// fixed-amount order among them, priced by hand and legitimately far from
/// the market, would draw a caution on a settlement that is perfectly honest.
/// Trades already in flight when the user updates would carry it. Declining
/// to apply a new check to a commitment that predates it is the same call
/// [orderFeeRateProvider] makes for the fee.
///
/// The four outcomes stay distinct. "Does not apply" and "could not be made"
/// are different facts about a settlement, and neither is "priced correctly":
/// a node can empty the currency tag or make the premium unreadable, so
/// silence on those would be a state it can put the screen into.
final marketCheckProvider =
    Provider.autoDispose.family<MarketCheckResult, String>((ref, orderId) {
  final session = ref.watch(sessionProvider(orderId));
  if (session?.termsPinned != true) return MarketCheckResult.notApplicable;
  if (session?.pinnedAmountSats != null) return MarketCheckResult.notApplicable;

  final settledSats = ref.watch(signedOrderAmountProvider(orderId));
  if (settledSats == null) return MarketCheckResult.notApplicable;

  final event = ref.watch(eventProvider(orderId));
  if (event == null) return MarketCheckResult.notApplicable;

  // A range order still advertising its band has not been resolved to the one
  // fiat figure this trade is for, so there is nothing to re-price yet.
  final fiat = event.fiatAmount;
  if (fiat.isRange() || fiat.minimum <= 0) {
    return MarketCheckResult.notApplicable;
  }

  // The rest of the inputs are ones the node publishes and can withhold. An
  // empty currency tag or an unreadable premium is a check that could not be
  // made, not one that came back clean.
  final fiatCode = event.currency;
  if (fiatCode == null || fiatCode.isEmpty) return MarketCheckResult.unavailable;

  // An absent premium is zero; one that is present and unreadable is not.
  // Quoting it as zero would misprice the order by exactly the premium and
  // turn an honest trade into a refusal.
  final premiumTag = event.premium;
  final premium = (premiumTag == null || premiumTag.trim().isEmpty)
      ? 0.0
      : double.tryParse(premiumTag.trim());
  if (premium == null) return MarketCheckResult.unavailable;

  final rate = ref.watch(independentFiatPerBtcProvider(fiatCode));
  if (rate.isLoading) return MarketCheckResult.loading;

  final fiatPerBtc = rate.valueOrNull;
  if (fiatPerBtc == null) return MarketCheckResult.unavailable;

  final check = MarketCheck.of(
    settledSats: settledSats,
    fiatAmount: fiat.minimum,
    fiatPerBtc: fiatPerBtc,
    premium: premium,
  );
  if (check == null) return MarketCheckResult.unavailable;

  return MarketCheckResult.checked(check);
});
