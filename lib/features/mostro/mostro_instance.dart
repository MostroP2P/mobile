import 'package:dart_nostr/nostr/model/event/event.dart';

/// Anti-abuse bond policy advertised by a Mostro daemon via the kind-38385
/// info event.
///
/// Three states must be distinguished:
/// - [unsupported]: the daemon does not emit the `bond_enabled` tag at all
///   (legacy daemon that predates the anti-abuse bond feature).
/// - [disabled]: the daemon emits `bond_enabled="false"`; the operator has
///   not enabled the feature.
/// - [enabled]: the daemon emits `bond_enabled="true"`; the bond is active
///   and the remaining six bond tags are present.
enum BondPolicy { unsupported, disabled, enabled }

/// Which side of a trade a bond applies to.
enum BondApplyTo { take, make, both }

class MostroInstance {
  final String pubKey;
  final String mostroVersion;
  final String commitHash;
  final int maxOrderAmount;
  final int minOrderAmount;
  final int expirationHours;
  final int expirationSeconds;
  final double fee;
  final int pow;
  final int holdInvoiceExpirationWindow;
  final int holdInvoiceCltvDelta;
  final int invoiceExpirationWindow;
  final String lndVersion;
  final String lndNodePublicKey;
  final String lndCommitHash;
  final String lndNodeAlias;
  final String supportedChains;
  final String supportedNetworks;
  final String lndNodeUri;
  final String fiatCurrenciesAccepted;
  final int maxOrdersPerResponse;

  /// Bond policy state. See [BondPolicy] for the three-state semantics.
  final BondPolicy bondPolicy;

  /// The following six fields carry the bond parameters and are only
  /// meaningful when [bondPolicy] is [BondPolicy.enabled]. They are null
  /// otherwise.
  final BondApplyTo? bondApplyTo;
  final bool? bondSlashOnWaitingTimeout;
  final double? bondAmountPct;
  final int? bondBaseAmountSats;
  final double? bondSlashNodeSharePct;
  final int? bondPayoutClaimWindowDays;

  MostroInstance(
    this.pubKey,
    this.mostroVersion,
    this.commitHash,
    this.maxOrderAmount,
    this.minOrderAmount,
    this.expirationHours,
    this.expirationSeconds,
    this.fee,
    this.pow,
    this.holdInvoiceExpirationWindow,
    this.holdInvoiceCltvDelta,
    this.invoiceExpirationWindow,
    this.lndVersion,
    this.lndNodePublicKey,
    this.lndCommitHash,
    this.lndNodeAlias,
    this.supportedChains,
    this.supportedNetworks,
    this.lndNodeUri,
    this.fiatCurrenciesAccepted,
    this.maxOrdersPerResponse, {
    this.bondPolicy = BondPolicy.unsupported,
    this.bondApplyTo,
    this.bondSlashOnWaitingTimeout,
    this.bondAmountPct,
    this.bondBaseAmountSats,
    this.bondSlashNodeSharePct,
    this.bondPayoutClaimWindowDays,
  });

  factory MostroInstance.fromEvent(NostrEvent event) {
    return MostroInstance(
      event.pubKey,
      event.mostroVersion,
      event.commitHash,
      event.maxOrderAmount,
      event.minOrderAmount,
      event.expirationHours,
      event.expirationSeconds,
      event.fee,
      event.pow,
      event.holdInvoiceExpirationWindow,
      event.holdInvoiceCltvDelta,
      event.invoiceExpirationWindow,
      event.lndVersion,
      event.lndNodePublicKey,
      event.lndCommitHash,
      event.lndNodeAlias,
      event.supportedChains,
      event.supportedNetworks,
      event.lndNodeUri,
      event.fiatCurrenciesAccepted,
      event.maxOrdersPerResponse,
      bondPolicy: event.bondPolicy,
      bondApplyTo: event.bondApplyTo,
      bondSlashOnWaitingTimeout: event.bondSlashOnWaitingTimeout,
      bondAmountPct: event.bondAmountPct,
      bondBaseAmountSats: event.bondBaseAmountSats,
      bondSlashNodeSharePct: event.bondSlashNodeSharePct,
      bondPayoutClaimWindowDays: event.bondPayoutClaimWindowDays,
    );
  }
}

extension MostroInstanceExtensions on NostrEvent {
  String _getTagValue(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1) ? tag[1] : 'Tag: $key not found';
  }

  /// Returns the tag value, or null when the tag is missing or empty.
  ///
  /// Use this for optional tags where absence is semantically meaningful
  /// (e.g. anti-abuse bond tags, which only appear on modern daemons).
  String? _getOptionalTagValue(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    if (tag == null || tag.length < 2) return null;
    return tag[1];
  }

  String get pubKey => _getTagValue('d');
  String get mostroVersion => _getTagValue('mostro_version');
  String get commitHash => _getTagValue('mostro_commit_hash');
  int get maxOrderAmount => int.parse(_getTagValue('max_order_amount'));
  int get minOrderAmount => int.parse(_getTagValue('min_order_amount'));
  int get expirationHours => int.parse(_getTagValue('expiration_hours'));
  int get expirationSeconds => int.parse(_getTagValue('expiration_seconds'));
  double get fee => double.parse(_getTagValue('fee'));
  int get pow => int.parse(_getTagValue('pow'));
  int get holdInvoiceExpirationWindow =>
      int.parse(_getTagValue('hold_invoice_expiration_window'));
  int get holdInvoiceCltvDelta =>
      int.parse(_getTagValue('hold_invoice_cltv_delta'));
  int get invoiceExpirationWindow =>
      int.parse(_getTagValue('invoice_expiration_window'));
  String get lndVersion => _getTagValue('lnd_version');
  String get lndNodePublicKey => _getTagValue('lnd_node_pubkey');
  String get lndCommitHash => _getTagValue('lnd_commit_hash');
  String get lndNodeAlias => _getTagValue('lnd_node_alias');
  String get supportedChains => _getTagValue('lnd_chains');
  String get supportedNetworks => _getTagValue('lnd_networks');
  String get lndNodeUri => _getTagValue('lnd_uris');
  String get fiatCurrenciesAccepted => _getTagValue('fiat_currencies_accepted');
  int get maxOrdersPerResponse =>
      int.parse(_getTagValue('max_orders_per_response'));

  /// Parses the anti-abuse bond policy from the `bond_enabled` tag.
  ///
  /// - Tag absent → [BondPolicy.unsupported] (legacy daemon).
  /// - `"true"` → [BondPolicy.enabled].
  /// - Any other value → [BondPolicy.disabled].
  BondPolicy get bondPolicy {
    final raw = _getOptionalTagValue('bond_enabled');
    if (raw == null) return BondPolicy.unsupported;
    return raw.toLowerCase() == 'true'
        ? BondPolicy.enabled
        : BondPolicy.disabled;
  }

  BondApplyTo? get bondApplyTo {
    final raw = _getOptionalTagValue('bond_apply_to');
    switch (raw) {
      case 'take':
        return BondApplyTo.take;
      case 'make':
        return BondApplyTo.make;
      case 'both':
        return BondApplyTo.both;
      default:
        return null;
    }
  }

  bool? get bondSlashOnWaitingTimeout {
    final raw = _getOptionalTagValue('bond_slash_on_waiting_timeout');
    if (raw == null) return null;
    return raw.toLowerCase() == 'true';
  }

  double? get bondAmountPct {
    final raw = _getOptionalTagValue('bond_amount_pct');
    return raw == null ? null : double.tryParse(raw);
  }

  int? get bondBaseAmountSats {
    final raw = _getOptionalTagValue('bond_base_amount_sats');
    return raw == null ? null : int.tryParse(raw);
  }

  double? get bondSlashNodeSharePct {
    final raw = _getOptionalTagValue('bond_slash_node_share_pct');
    return raw == null ? null : double.tryParse(raw);
  }

  int? get bondPayoutClaimWindowDays {
    final raw = _getOptionalTagValue('bond_payout_claim_window_days');
    return raw == null ? null : int.tryParse(raw);
  }
}
