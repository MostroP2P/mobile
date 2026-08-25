import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/invoice_terms.dart';

/// A data part long enough to look real. Nothing reads it — the check is
/// about the amount in the prefix — but a prefix with nothing behind it is
/// not an invoice.
const _data = 'pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfq';

/// `sats` satoshis expressed the way an invoice does, in nano-bitcoin: one
/// satoshi is ten nano-bitcoin.
String invoiceFor(int sats) => 'lnbc${sats * 10}n1$_data';

void main() {
  group('InvoiceTerms.check', () {
    test('accepts an invoice for exactly the order amount', () {
      final terms = InvoiceTerms.check(
        invoice: invoiceFor(50000),
        expectedSats: 50000,
      );

      expect(terms.isPayable, isTrue);
      expect(terms.problem, isNull);
      expect(terms.amountSats, 50000);
    });

    // The finding's scenario: the message shows one figure and carries an
    // invoice for another, and the wallet honours the invoice.
    test('refuses an invoice that asks for more than the order says', () {
      final terms = InvoiceTerms.check(
        invoice: invoiceFor(500000),
        expectedSats: 50000,
      );

      expect(terms.isPayable, isFalse);
      expect(terms.problem, InvoiceTermsProblem.amountMismatch);
      // What it would really have sent is still readable, for the screen to
      // show alongside what the order said.
      expect(terms.amountSats, 500000);
    });

    test('refuses an invoice that asks for less than the order says', () {
      final terms = InvoiceTerms.check(
        invoice: invoiceFor(10000),
        expectedSats: 50000,
      );

      expect(terms.problem, InvoiceTermsProblem.amountMismatch);
    });

    test('refuses a difference smaller than one satoshi', () {
      // 50000 sats is 500000000 pico-bitcoin; one millisatoshi more is a
      // different invoice that reads identically at satoshi resolution.
      final terms = InvoiceTerms.check(
        invoice: 'lnbc500000010p1$_data',
        expectedSats: 50000,
      );

      expect(terms.problem, InvoiceTermsProblem.amountMismatch);
      expect(terms.amountSats, 50000);
    });

    test('refuses an invoice that sets no amount', () {
      // The wallet would choose how much to send.
      final terms = InvoiceTerms.check(
        invoice: 'lnbc1$_data',
        expectedSats: 50000,
      );

      expect(terms.problem, InvoiceTermsProblem.amountMissing);
      expect(terms.amountSats, isNull);
    });

    test('refuses an invoice it cannot read', () {
      final terms = InvoiceTerms.check(
        invoice: 'not-an-invoice',
        expectedSats: 50000,
      );

      expect(terms.problem, InvoiceTermsProblem.unreadable);
      expect(terms.invoice, isNull);
    });

    test('refuses an empty invoice', () {
      final terms = InvoiceTerms.check(invoice: '', expectedSats: 50000);

      expect(terms.problem, InvoiceTermsProblem.unreadable);
    });

    test('reports, without refusing, an order with no amount to check against',
        () {
      // Nothing about the invoice contradicts the order, so this qualifies
      // the payment rather than stopping it: refusing would make an absent
      // term stronger evidence than a disagreeing one.
      for (final expected in <int?>[null, 0, -1]) {
        final terms = InvoiceTerms.check(
          invoice: invoiceFor(50000),
          expectedSats: expected,
        );

        expect(terms.problem, InvoiceTermsProblem.termsUnknown,
            reason: 'expectedSats: $expected');
        expect(terms.isUnverifiable, isTrue, reason: 'expectedSats: $expected');
        expect(terms.isPayable, isTrue, reason: 'expectedSats: $expected');
      }
    });

    test('refuses every problem that contradicts the order', () {
      // The distinction the screen rests on: these are disagreements, not
      // absences.
      expect(
        InvoiceTerms.check(invoice: '', expectedSats: 50000).isPayable,
        isFalse,
      );
      expect(
        InvoiceTerms.check(invoice: invoiceFor(90000), expectedSats: 50000)
            .isPayable,
        isFalse,
      );
    });

    test('reads the amount off the invoice, not off the order', () {
      final terms = InvoiceTerms.check(
        invoice: invoiceFor(250000),
        expectedSats: 250000,
      );

      expect(terms.amountSats, 250000);
      expect(terms.invoice, isNotNull);
    });
  });
}
