import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/order/providers/settlement_anchor_provider.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/services/yadio_exchange_service.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/session_notifier_provider.dart';
import 'package:mostro_mobile/shared/utils/market_quote.dart';

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
/// Null rather than an error when the rate cannot be had: this check is a
/// second opinion, and being offline is not evidence against a settlement.
final independentFiatPerBtcProvider =
    FutureProvider.family<double?, String>((ref, fiatCode) async {
  if (fiatCode.isEmpty) return null;

  try {
    final service = ref.watch(independentExchangeServiceProvider);
    return await service.getExchangeRate(fiatCode, 'BTC');
  } catch (e) {
    logger.w('Independent rate for $fiatCode unavailable: $e');
    return null;
  }
});

/// Re-prices [orderId] against the independent rate, or null when the check
/// does not apply or cannot be made.
///
/// Only runs where the client holds no figure of its own. A session that
/// pinned the sats amount at commitment is already held to what the user saw
/// on the take screen, and re-pricing it would only second-guess a number
/// they accepted with their eyes open: a fixed-amount order may sit off the
/// market on purpose. What is left is the market-price and range orders,
/// whose sats the node resolved after the commitment, and sessions from
/// before the pin existed.
final marketCheckProvider =
    Provider.family<MarketCheck?, String>((ref, orderId) {
  final session = ref.watch(sessionProvider(orderId));
  if (session?.pinnedAmountSats != null) return null;

  final settledSats = ref.watch(signedOrderAmountProvider(orderId));
  if (settledSats == null) return null;

  final event = ref.watch(eventProvider(orderId));
  if (event == null) return null;

  final fiatCode = event.currency;
  if (fiatCode == null || fiatCode.isEmpty) return null;

  // A range order still advertising its band has not been resolved to the one
  // fiat figure this trade is for, so there is nothing to re-price yet.
  final fiat = event.fiatAmount;
  if (fiat.isRange() || fiat.minimum <= 0) return null;

  // An absent premium is zero; one that is present and unreadable is not.
  // Quoting it as zero would misprice the order by exactly the premium and
  // turn an honest trade into a refusal.
  final premiumTag = event.premium;
  final premium = (premiumTag == null || premiumTag.trim().isEmpty)
      ? 0.0
      : double.tryParse(premiumTag.trim());
  if (premium == null) return null;

  final fiatPerBtc =
      ref.watch(independentFiatPerBtcProvider(fiatCode)).valueOrNull;
  if (fiatPerBtc == null) return null;

  return MarketCheck.of(
    settledSats: settledSats,
    fiatAmount: fiat.minimum,
    fiatPerBtc: fiatPerBtc,
    premium: premium,
  );
});
