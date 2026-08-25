import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:mostro_mobile/features/mostro/transport.dart';

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

  /// Wire transport advertised via the `protocol_version` tag (§2 of the
  /// transport v2 migration), in the three states the tag can be in: the
  /// version it names, [kLegacyProtocolVersion] when the tag is absent, and
  /// null when it is present but unusable.
  ///
  /// Nullable because those last two are different facts. Reading a malformed
  /// value as v1 is the conflation [advertisesProtocolVersion] exists to avoid,
  /// and it would show a node whose transport actually resolved to v2 as
  /// speaking v1. This field is display state — the transport itself comes from
  /// [anchoredProtocolVersionFor], never from here.
  final int? protocolVersion;

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
    this.protocolVersion,
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
      protocolVersion: event.assertedProtocolVersion,
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
    final tag = tags?.firstWhere(
      (t) => t.isNotEmpty && t[0] == key,
      orElse: () => const <String>[],
    );
    return (tag != null && tag.length > 1) ? tag[1] : 'Tag: $key not found';
  }

  /// Returns the tag value, or null when the tag is missing or empty.
  ///
  /// Use this for optional tags where absence is semantically meaningful
  /// (e.g. anti-abuse bond tags, which only appear on modern daemons).
  ///
  /// Empty or whitespace-only values are treated as missing so they cannot
  /// be misparsed as legitimate data downstream (e.g. an empty
  /// `bond_enabled=""` would otherwise be classified as `disabled` instead
  /// of `unsupported`, breaking the three-state semantics).
  String? _getOptionalTagValue(String key) {
    final tag = tags?.firstWhere(
      (t) => t.isNotEmpty && t[0] == key,
      orElse: () => const <String>[],
    );
    if (tag == null || tag.length < 2) return null;
    final value = tag[1].trim();
    return value.isEmpty ? null : value;
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

  /// Parses the wire transport version from the `protocol_version` tag (§2).
  ///
  /// Returns `null` when the tag is absent, empty or unparseable. Those are
  /// not the same fact, and callers deciding a transport must not treat them
  /// alike — pair this with [advertisesProtocolVersion] to tell them apart.
  int? get protocolVersion {
    final raw = _getOptionalTagValue('protocol_version');
    return raw == null ? null : int.tryParse(raw);
  }

  /// Whether the event carries a `protocol_version` tag at all, regardless of
  /// whether its value parses.
  ///
  /// This is the half of the story [protocolVersion] cannot tell. A daemon
  /// before v0.18.0 emits no tag, and on a verified event that silence *is* an
  /// assertion of v1. A tag holding `""` or `abc` asserts nothing: the node
  /// meant to state a version and the value is unusable, so the client has no
  /// evidence and must fall back to its safe default rather than read the
  /// malformed value as legacy and pair itself with gift wrap.
  bool get advertisesProtocolVersion =>
      tags?.any((t) => t.isNotEmpty && t[0] == 'protocol_version') ?? false;

  /// What this event asserts about its transport, resolving the three states
  /// [protocolVersion] and [advertisesProtocolVersion] describe between them:
  ///
  /// - Tag present and parseable → that version, whatever it is. What to do
  ///   with one this client does not speak is `resolveTransport`'s call.
  /// - Tag absent entirely → [kLegacyProtocolVersion]. Silence from a verified
  ///   event is a pre-v0.18.0 daemon asserting v1 by omission.
  /// - Tag present but unusable → null. The node meant to state a version and
  ///   the value says nothing, so there is no evidence to act on.
  ///
  /// The single reading of the tag, so display and transport resolution cannot
  /// disagree about what a node claims.
  int? get assertedProtocolVersion {
    final parsed = protocolVersion;
    if (parsed != null) return parsed;
    return advertisesProtocolVersion ? null : kLegacyProtocolVersion;
  }

  /// Parses the anti-abuse bond policy from the `bond_enabled` tag.
  ///
  /// - Tag absent → [BondPolicy.unsupported] (legacy daemon).
  /// - `"true"` → [BondPolicy.enabled].
  /// - `"false"` → [BondPolicy.disabled].
  /// - Any other value → [BondPolicy.unsupported] (defensive: malformed
  ///   payloads must not masquerade as an intentional policy state).
  BondPolicy get bondPolicy {
    final raw = _getOptionalTagValue('bond_enabled')?.toLowerCase();
    switch (raw) {
      case 'true':
        return BondPolicy.enabled;
      case 'false':
        return BondPolicy.disabled;
      default:
        return BondPolicy.unsupported;
    }
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

  /// Parses `bond_slash_on_waiting_timeout`. Returns `null` for any value
  /// other than `"true"` or `"false"` (case-insensitive) so malformed data
  /// is not silently collapsed into a valid policy state.
  bool? get bondSlashOnWaitingTimeout {
    final raw = _getOptionalTagValue('bond_slash_on_waiting_timeout')
        ?.toLowerCase();
    if (raw == 'true') return true;
    if (raw == 'false') return false;
    return null;
  }

  /// Bond fraction of the order amount. Must be a percentage in `[0.0, 1.0]`;
  /// out-of-range values are treated as invalid and yield `null`.
  double? get bondAmountPct {
    final raw = _getOptionalTagValue('bond_amount_pct');
    final value = raw == null ? null : double.tryParse(raw);
    if (value == null) return null;
    return (value >= 0.0 && value <= 1.0) ? value : null;
  }

  /// Minimum bond floor in sats. Negative values are treated as invalid.
  int? get bondBaseAmountSats {
    final raw = _getOptionalTagValue('bond_base_amount_sats');
    final value = raw == null ? null : int.tryParse(raw);
    if (value == null) return null;
    return value >= 0 ? value : null;
  }

  /// Node share of a slashed bond. Spec constrains this to `[0.0, 1.0]`;
  /// out-of-range values are treated as invalid and yield `null`.
  double? get bondSlashNodeSharePct {
    final raw = _getOptionalTagValue('bond_slash_node_share_pct');
    final value = raw == null ? null : double.tryParse(raw);
    if (value == null) return null;
    return (value >= 0.0 && value <= 1.0) ? value : null;
  }

  /// Payout claim window in days. Must be positive; non-positive or
  /// unparseable values yield `null`.
  int? get bondPayoutClaimWindowDays {
    final raw = _getOptionalTagValue('bond_payout_claim_window_days');
    final value = raw == null ? null : int.tryParse(raw);
    if (value == null) return null;
    return value > 0 ? value : null;
  }
}
