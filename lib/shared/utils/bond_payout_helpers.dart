import 'package:mostro_mobile/data/models/bond_payout_request.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/payment_request.dart';

DateTime bondClaimDeadline(int slashedAt, int claimWindowDays) {
  return DateTime.fromMillisecondsSinceEpoch(
    (slashedAt + claimWindowDays * 86400) * 1000,
    isUtc: true,
  ).toLocal();
}

bool isBondClaimExpired(int slashedAt, int claimWindowDays) {
  return DateTime.now().isAfter(bondClaimDeadline(slashedAt, claimWindowDays));
}

/// Latest inbound `BondPayoutRequest` for the order, picked by timestamp
/// regardless of input ordering. `null` when the most recent
/// `add-bond-invoice` is an outbound `PaymentRequest` reply or absent.
BondPayoutRequest? latestBondPayoutRequest(List<MostroMessage> messages) {
  final sorted = [...messages]..sort(
      (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
    );
  for (final msg in sorted) {
    if (msg.action != Action.addBondInvoice) continue;
    final payload = msg.payload;
    if (payload is BondPayoutRequest) return payload;
    if (payload is PaymentRequest) return null;
  }
  return null;
}

/// True when the latest stored `add-bond-invoice` for the order is an
/// inbound `BondPayoutRequest` whose claim window has not expired and to
/// which the user has not yet replied with a `PaymentRequest`.
bool hasPendingBondClaim(
  List<MostroMessage> messages,
  int claimWindowDays,
) {
  final request = latestBondPayoutRequest(messages);
  if (request == null) return false;
  return !isBondClaimExpired(request.slashedAt, claimWindowDays);
}
