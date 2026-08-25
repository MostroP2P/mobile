import 'package:mostro_mobile/shared/utils/bolt11.dart';

/// Why an invoice cannot be reconciled with the trade it is supposed to
/// settle.
enum InvoiceTermsProblem {
  /// The string is not a BOLT-11 invoice this app can read.
  unreadable,

  /// The invoice encodes no amount, leaving the figure to the payer's wallet.
  amountMissing,

  /// The order carries no amount to check the invoice against.
  termsUnknown,

  /// The invoice asks for something other than what the order says.
  amountMismatch,
}

/// The result of holding an invoice against the terms of the order it belongs
/// to.
///
/// The amount shown on screen and the amount encoded in the invoice arrive by
/// different routes and were never reconciled: the figure came from the
/// order in the message, the payment came from the invoice string in the same
/// message, and nothing compared them. A wallet honours the invoice, so the
/// figure on screen decided nothing.
///
/// Every failure is refusal, not a warning. There is no reading of an
/// unreadable invoice, or of one that lets the wallet choose the amount, that
/// makes it safe to pay — and the order is the only statement of what this
/// payment is for.
class InvoiceTerms {
  /// What the invoice turned out to say, when it could be read at all.
  final Bolt11Invoice? invoice;

  /// What stops this invoice from being paid, or null when nothing does.
  final InvoiceTermsProblem? problem;

  const InvoiceTerms._({this.invoice, this.problem});

  /// Whether the invoice may be paid from here.
  ///
  /// [InvoiceTermsProblem.termsUnknown] is the one problem that qualifies the
  /// payment rather than refusing it: nothing about the invoice contradicts
  /// the order, there is simply no order figure to check it against. Refusing
  /// there would make an absent term stronger evidence than a disagreeing
  /// one, and it is the same state the rest of the flow reports as a check it
  /// could not make. The caller says so out loud instead.
  bool get isPayable =>
      problem == null || problem == InvoiceTermsProblem.termsUnknown;

  /// Whether the invoice was read but had nothing to be checked against.
  bool get isUnverifiable => problem == InvoiceTermsProblem.termsUnknown;

  /// Satoshis the invoice asks for, from the invoice itself rather than from
  /// the message that carried it. Null when it could not be read.
  int? get amountSats => invoice?.amountSats;

  /// Checks [invoice] against [expectedSats], the amount the order says this
  /// payment is for.
  static InvoiceTerms check({
    required String invoice,
    required int? expectedSats,
  }) {
    final decoded = Bolt11Invoice.tryParse(invoice);
    if (decoded == null) {
      return const InvoiceTerms._(problem: InvoiceTermsProblem.unreadable);
    }

    final amountMsat = decoded.amountMsat;
    if (amountMsat == null) {
      return InvoiceTerms._(
        invoice: decoded,
        problem: InvoiceTermsProblem.amountMissing,
      );
    }

    if (expectedSats == null || expectedSats <= 0) {
      return InvoiceTerms._(
        invoice: decoded,
        problem: InvoiceTermsProblem.termsUnknown,
      );
    }

    // Compared in millisatoshis: at satoshi resolution two invoices differing
    // by less than a satoshi read as equal.
    if (amountMsat != BigInt.from(expectedSats) * BigInt.from(1000)) {
      return InvoiceTerms._(
        invoice: decoded,
        problem: InvoiceTermsProblem.amountMismatch,
      );
    }

    return InvoiceTerms._(invoice: decoded);
  }
}
