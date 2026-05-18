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

/// True when the latest stored `add-bond-invoice` for the order is an
/// inbound `BondPayoutRequest` whose claim window has not expired and to
/// which the user has not yet replied with a `PaymentRequest`.
bool hasPendingBondClaim(
  List<MostroMessage> messages,
  int claimWindowDays,
) {
  final sorted = [...messages]..sort(
      (a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0),
    );
  for (final msg in sorted) {
    if (msg.action != Action.addBondInvoice) continue;
    final payload = msg.payload;
    if (payload is BondPayoutRequest) {
      return !isBondClaimExpired(payload.slashedAt, claimWindowDays);
    }
    if (payload is PaymentRequest) return false;
  }
  return false;
}
