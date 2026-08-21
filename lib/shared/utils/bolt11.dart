/// The Lightning networks a BOLT-11 invoice can name in its prefix.
enum Bolt11Network {
  mainnet('bc'),
  testnet('tb'),
  signet('tbs'),
  regtest('bcrt'),
  simnet('sb');

  const Bolt11Network(this.prefix);

  /// The network part of the `ln` prefix, without the leading `ln`.
  final String prefix;
}

/// What a BOLT-11 invoice states in its human-readable prefix: which network
/// it is for, and how much it asks for.
///
/// Only the prefix is read. The amount and the network are the whole of it —
/// everything else (payment hash, expiry, routing hints) lives in the bech32
/// data part behind a tagged-field encoding this deliberately does not touch.
/// Parsing less means less of this app interpreting a string chosen by
/// whoever sent the invoice.
///
/// The prefix is enough for the question the app actually has to answer
/// before paying: is this invoice for the amount the trade says it is. The
/// amount is not optional there — an invoice that encodes none lets the
/// wallet pick, which is the ambiguity that has to be refused rather than
/// resolved.
class Bolt11Invoice {
  /// The network the invoice is drawn on.
  final Bolt11Network network;

  /// Millisatoshis the invoice asks for, or null when it encodes no amount
  /// and leaves the figure to the payer.
  final BigInt? amountMsat;

  const Bolt11Invoice({required this.network, required this.amountMsat});

  /// Whole satoshis the invoice asks for, truncating any sub-satoshi
  /// remainder. Null when the invoice encodes no amount.
  ///
  /// Compare in [amountMsat] rather than here: a millisatoshi remainder is
  /// invisible at this resolution, and two invoices that differ by less than
  /// a satoshi would look equal.
  int? get amountSats =>
      amountMsat == null ? null : (amountMsat! ~/ BigInt.from(1000)).toInt();

  /// Every amount is expressed as a multiple of this many millisatoshis,
  /// per the multiplier that follows the figure. Bitcoin's own supply cap
  /// bounds anything a real invoice can ask for.
  static final BigInt _msatPerBtc = BigInt.from(100000000000);
  static final BigInt _maxMsat = BigInt.from(21000000) * _msatPerBtc;

  /// Multipliers BOLT-11 defines, as the fraction of a bitcoin each denotes.
  /// `p` is finer than a millisatoshi, so an amount using it has to land on a
  /// whole one.
  static final Map<String, BigInt> _multipliers = {
    'm': BigInt.from(100000000),
    'u': BigInt.from(100000),
    'n': BigInt.from(100),
  };

  /// Reads [invoice]'s prefix, or returns null if it is not one this app is
  /// willing to act on.
  ///
  /// Null covers every reason equally on purpose — a malformed prefix, an
  /// unknown network, an amount that overflows or is not expressible. The
  /// caller has one decision to make and no use for the distinction: an
  /// invoice whose terms cannot be read is one that must not be paid.
  static Bolt11Invoice? tryParse(String invoice) {
    final normalized = invoice.trim().toLowerCase();
    if (!normalized.startsWith('ln')) return null;

    // The bech32 charset has no `1`, so every `1` in the string belongs to the
    // prefix except the last, which separates it from the data part.
    final separator = normalized.lastIndexOf('1');
    if (separator < 0) return null;

    final prefixBody = normalized.substring(2, separator);
    if (prefixBody.isEmpty) return null;

    // The data part is what carries the payment hash and the signature. An
    // invoice with none is a prefix, not an invoice.
    if (separator == normalized.length - 1) return null;

    final network = _networkOf(prefixBody);
    if (network == null) return null;

    final amountPart = prefixBody.substring(network.prefix.length);
    if (amountPart.isEmpty) {
      return Bolt11Invoice(network: network, amountMsat: null);
    }

    final amountMsat = _amountMsatOf(amountPart);
    if (amountMsat == null) return null;

    return Bolt11Invoice(network: network, amountMsat: amountMsat);
  }

  /// Longest prefix wins: `bc` is a prefix of `bcrt`, and `tb` of `tbs`, so
  /// matching in declaration order would read every regtest invoice as
  /// mainnet.
  static Bolt11Network? _networkOf(String prefixBody) {
    Bolt11Network? match;
    for (final network in Bolt11Network.values) {
      if (!prefixBody.startsWith(network.prefix)) continue;
      if (match == null || network.prefix.length > match.prefix.length) {
        match = network;
      }
    }
    return match;
  }

  /// Parses the figure and its multiplier, in millisatoshis.
  ///
  /// Held in [BigInt] until the range check: the figure comes from the
  /// invoice, so nothing stops it being long enough to wrap a 64-bit int and
  /// land on a small, plausible-looking number.
  static BigInt? _amountMsatOf(String amountPart) {
    final last = amountPart[amountPart.length - 1];
    final hasMultiplier = !_isDigit(last);

    final digits = hasMultiplier
        ? amountPart.substring(0, amountPart.length - 1)
        : amountPart;
    if (digits.isEmpty || !digits.split('').every(_isDigit)) return null;

    // A leading zero is not a valid BOLT-11 amount, and `0` itself would mean
    // an invoice asking for nothing.
    if (digits.startsWith('0')) return null;

    final value = BigInt.tryParse(digits);
    if (value == null || value == BigInt.zero) return null;

    final BigInt msat;
    if (!hasMultiplier) {
      msat = value * _msatPerBtc;
    } else if (last == 'p') {
      // A tenth of a millisatoshi each: only whole millisatoshis are payable.
      if (value % BigInt.from(10) != BigInt.zero) return null;
      msat = value ~/ BigInt.from(10);
    } else {
      final multiplier = _multipliers[last];
      if (multiplier == null) return null;
      msat = value * multiplier;
    }

    if (msat <= BigInt.zero || msat > _maxMsat) return null;
    return msat;
  }

  static bool _isDigit(String c) {
    final code = c.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  @override
  String toString() =>
      'Bolt11Invoice(network: ${network.name}, amountMsat: $amountMsat)';
}
