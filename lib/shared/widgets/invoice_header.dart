import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/user_info.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/shared/widgets/order_cards.dart';

/// Header shown on the add/pay invoice screens: who took the order, the
/// amounts to pay or invoice, the order id and the counterpart's reputation.
/// Everything is left aligned and shares one text size and weight scale.
///
/// The two flows are mirror images: paying the hold invoice means the user is
/// the seller and the taker is the buyer; adding an invoice means the user is
/// the buyer and the taker is the seller.
class InvoiceHeader extends StatelessWidget {
  final bool userIsSeller;
  final int sats;
  final String fiatAmount;
  final String fiatCode;
  final String orderId;
  final UserInfo? reputation;

  const InvoiceHeader({
    super.key,
    required this.userIsSeller,
    required this.sats,
    required this.fiatAmount,
    required this.fiatCode,
    required this.orderId,
    this.reputation,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    const bodyStyle = TextStyle(color: AppTheme.textPrimary, fontSize: 16);
    final boldStyle = bodyStyle.copyWith(fontWeight: FontWeight.w600);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          userIsSeller ? s.buyerTookYourSellOrder : s.sellerTookYourBuyOrder,
          style: boldStyle,
        ),
        const SizedBox(height: 8),
        Text(
          userIsSeller
              ? s.payInvoiceExchangeInstruction(
                  sats.toString(), fiatAmount, fiatCode)
              : s.addInvoiceExchangeInstruction(
                  sats.toString(), fiatAmount, fiatCode),
          style: bodyStyle,
        ),
        const SizedBox(height: 12),
        // Text.rich (not RichText) so the line inherits the theme font
        Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${s.orderIdLabel}: ', style: boldStyle),
              TextSpan(text: orderId),
            ],
          ),
          style: bodyStyle,
        ),
        if (reputation != null) ...[
          const SizedBox(height: 12),
          PeerReputationInline(
            reputation: reputation!,
            counterpartIsBuyer: userIsSeller,
          ),
        ],
      ],
    );
  }
}
