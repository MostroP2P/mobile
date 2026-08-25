import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';

/// The three figures the independent market quote is priced from.
class PricingTerms {
  final String fiatCode;
  final int fiatAmount;
  final double premium;

  const PricingTerms({
    required this.fiatCode,
    required this.fiatAmount,
    required this.premium,
  });
}

/// Reads the pricing terms out of a kind-38383 order [event].
///
/// Null when the event is missing or does not carry a usable set. A partial
/// pin would be worse than none: the quote would be priced from a mix of what
/// was agreed and what the node says now, which is the thing pinning exists to
/// stop.
///
/// A range order that has not been resolved to one fiat figure yields null
/// too — there is no single figure to pin until a taker settles the band.
PricingTerms? pricingTermsOf(NostrEvent? event) {
  if (event == null) return null;

  final fiatCode = event.currency;
  if (fiatCode == null || fiatCode.isEmpty) return null;

  final fiat = event.fiatAmount;
  if (fiat.isRange() || fiat.minimum <= 0) return null;

  // An absent premium is zero; one that is present and unreadable is not.
  final premiumTag = event.premium;
  final premium = (premiumTag == null || premiumTag.trim().isEmpty)
      ? 0.0
      : double.tryParse(premiumTag.trim());
  if (premium == null || !premium.isFinite) return null;

  return PricingTerms(
    fiatCode: fiatCode,
    fiatAmount: fiat.minimum,
    premium: premium,
  );
}
