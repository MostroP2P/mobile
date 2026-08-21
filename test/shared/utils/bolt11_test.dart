import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/shared/utils/bolt11.dart';

/// A data part long enough to look real. Nothing here reads it — the prefix
/// is the whole subject — but `tryParse` refuses a prefix with no data behind
/// it, so every case needs one.
const _data = 'pvjluezpp5qqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfqqqsyqcyq5rqwzqfq';

BigInt _msat(String value) => BigInt.parse(value);

void main() {
  group('Bolt11Invoice.tryParse amounts', () {
    // The multiplier table, each against the figure the spec gives for it.
    test('reads a milli-bitcoin amount', () {
      final parsed = Bolt11Invoice.tryParse('lnbc2500m1$_data');

      expect(parsed!.amountMsat, _msat('250000000000'));
      expect(parsed.amountSats, 250000000);
    });

    test('reads a micro-bitcoin amount', () {
      final parsed = Bolt11Invoice.tryParse('lnbc2500u1$_data');

      // 2500 × 10⁻⁶ BTC = 250 000 sats.
      expect(parsed!.amountMsat, _msat('250000000'));
      expect(parsed.amountSats, 250000);
    });

    test('reads a nano-bitcoin amount', () {
      final parsed = Bolt11Invoice.tryParse('lnbc20n1$_data');

      expect(parsed!.amountMsat, _msat('2000'));
      expect(parsed.amountSats, 2);
    });

    test('reads a pico-bitcoin amount', () {
      // Ten pico-bitcoin is one millisatoshi.
      final parsed = Bolt11Invoice.tryParse('lnbc9678785340p1$_data');

      expect(parsed!.amountMsat, _msat('967878534'));
    });

    test('reads an amount with no multiplier as whole bitcoin', () {
      final parsed = Bolt11Invoice.tryParse('lnbc11$_data');

      expect(parsed!.amountMsat, _msat('100000000000'));
      expect(parsed.amountSats, 100000000);
    });

    test('reads an invoice that encodes no amount', () {
      final parsed = Bolt11Invoice.tryParse('lnbc1$_data');

      expect(parsed, isNotNull);
      expect(parsed!.amountMsat, isNull);
      expect(parsed.amountSats, isNull);
      expect(parsed.network, Bolt11Network.mainnet);
    });

    test('truncates a sub-satoshi remainder in amountSats only', () {
      // 1 pico-bitcoin steps are finer than a satoshi.
      final parsed = Bolt11Invoice.tryParse('lnbc10010p1$_data');

      expect(parsed!.amountMsat, _msat('1001'));
      expect(parsed.amountSats, 1);
    });
  });

  group('Bolt11Invoice.tryParse networks', () {
    test('reads each network prefix', () {
      expect(Bolt11Invoice.tryParse('lnbc2500u1$_data')!.network,
          Bolt11Network.mainnet);
      expect(Bolt11Invoice.tryParse('lntb2500u1$_data')!.network,
          Bolt11Network.testnet);
      expect(Bolt11Invoice.tryParse('lnsb2500u1$_data')!.network,
          Bolt11Network.simnet);
    });

    // `bc` is a prefix of `bcrt` and `tb` of `tbs`. Matching in declaration
    // order would read every regtest invoice as a mainnet one, and the amount
    // would be parsed out of `rt2500u`.
    test('prefers the longest matching prefix', () {
      final regtest = Bolt11Invoice.tryParse('lnbcrt2500u1$_data');
      expect(regtest!.network, Bolt11Network.regtest);
      expect(regtest.amountMsat, _msat('250000000'));

      final signet = Bolt11Invoice.tryParse('lntbs2500u1$_data');
      expect(signet!.network, Bolt11Network.signet);
      expect(signet.amountMsat, _msat('250000000'));
    });

    test('refuses a network it does not know', () {
      expect(Bolt11Invoice.tryParse('lnxyz2500u1$_data'), isNull);
    });
  });

  group('Bolt11Invoice.tryParse rejections', () {
    test('refuses a string that is not an invoice', () {
      expect(Bolt11Invoice.tryParse(''), isNull);
      expect(Bolt11Invoice.tryParse('not-an-invoice'), isNull);
      expect(Bolt11Invoice.tryParse('bc2500u1$_data'), isNull);
    });

    test('refuses a prefix with no data part behind it', () {
      expect(Bolt11Invoice.tryParse('lnbc2500u1'), isNull);
      expect(Bolt11Invoice.tryParse('lnbc2500u'), isNull);
    });

    test('refuses an empty prefix body', () {
      expect(Bolt11Invoice.tryParse('ln1$_data'), isNull);
    });

    test('refuses a multiplier that is not one of m, u, n, p', () {
      expect(Bolt11Invoice.tryParse('lnbc2500k1$_data'), isNull);
      expect(Bolt11Invoice.tryParse('lnbc2500x1$_data'), isNull);
    });

    test('refuses a multiplier with no figure in front of it', () {
      expect(Bolt11Invoice.tryParse('lnbcu1$_data'), isNull);
    });

    test('refuses an amount of zero', () {
      expect(Bolt11Invoice.tryParse('lnbc0u1$_data'), isNull);
    });

    test('refuses a leading zero', () {
      // Otherwise `0250u` and `250u` are the same invoice with two spellings.
      expect(Bolt11Invoice.tryParse('lnbc0250u1$_data'), isNull);
    });

    test('refuses a pico amount finer than a millisatoshi', () {
      // 1p is a tenth of a millisatoshi; nothing can pay it.
      expect(Bolt11Invoice.tryParse('lnbc1p1$_data'), isNull);
      expect(Bolt11Invoice.tryParse('lnbc15p1$_data'), isNull);
    });

    // The figure comes from whoever wrote the invoice. Held in an int it
    // could wrap and land on a small, plausible-looking amount, which is
    // exactly the confusion the caller is trying to close.
    test('refuses an amount beyond what bitcoin can express', () {
      // The whole supply is expressible, one satoshi more is not.
      expect(
        Bolt11Invoice.tryParse('lnbc210000001$_data')!.amountMsat,
        _msat('2100000000000000000'),
      );
      expect(Bolt11Invoice.tryParse('lnbc210000011$_data'), isNull);
      expect(
        Bolt11Invoice.tryParse('lnbc99999999999999999999999999991$_data'),
        isNull,
      );
    });

    test('refuses a figure that is not digits', () {
      expect(Bolt11Invoice.tryParse('lnbc2a00u1$_data'), isNull);
      expect(Bolt11Invoice.tryParse('lnbc-250u1$_data'), isNull);
    });
  });

  group('Bolt11Invoice.tryParse normalization', () {
    test('reads an all-uppercase invoice', () {
      // BOLT-11 allows the uppercase spelling for QR efficiency.
      final parsed = Bolt11Invoice.tryParse('LNBC2500U1${_data.toUpperCase()}');

      expect(parsed!.network, Bolt11Network.mainnet);
      expect(parsed.amountMsat, _msat('250000000'));
    });

    test('ignores surrounding whitespace', () {
      final parsed = Bolt11Invoice.tryParse('  lnbc2500u1$_data\n');

      expect(parsed!.amountMsat, _msat('250000000'));
    });

    test('takes the last 1 as the separator', () {
      // The figure can contain a 1, and the bech32 charset cannot, so the
      // separator is always the last one in the string.
      final parsed = Bolt11Invoice.tryParse('lnbc1500u1$_data');

      expect(parsed!.amountMsat, _msat('150000000'));
    });
  });
}
