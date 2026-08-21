import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/utils/settlement_amounts.dart';

/// The order amount the node has published for [orderId], in satoshis.
///
/// Read off the kind-38383 order event rather than the direct message that
/// asks for the payment. Both come from the node, but only one of them is the
/// order the user chose: the event is addressable and public, and it is what
/// the take screen showed. A market-price order carries no amount until it is
/// taken, and the node republishes the event with the resolved figure as part
/// of that flow, so by the time either side is asked to act the amount is
/// there.
///
/// Null when no event has arrived, or when it carries no usable amount.
final signedOrderAmountProvider = Provider.family<int?, String>((ref, orderId) {
  final event = ref.watch(eventProvider(orderId));
  if (event == null) return null;

  final amount = int.tryParse(event.amount ?? '');
  if (amount == null || amount <= 0) return null;
  return amount;
});

/// The node's fee rate, from its kind-38385 info event.
///
/// Null when the info event has not arrived or does not carry the tag. The
/// getter parses eagerly and throws on a missing tag, which is fine for the
/// About screen it was written for and not for a payment check.
final nodeFeeRateProvider = Provider<double?>((ref) {
  final info = ref.read(orderRepositoryProvider).mostroInstance;
  if (info == null) return null;
  try {
    return info.fee;
  } catch (e) {
    logger.w('Node info event carries no usable fee rate: $e');
    return null;
  }
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
  final feeRate = ref.watch(nodeFeeRateProvider);
  if (amountSats == null || feeRate == null) return null;

  return SettlementAmounts.sellerPays(
    amountSats: amountSats,
    feeRate: feeRate,
  );
});
