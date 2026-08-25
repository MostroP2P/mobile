import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The terms a trade committed to, as they stood at the moment of commitment.
///
/// Every field here is something the node publishes in an addressable event
/// and can republish afterwards. Holding the values the user actually agreed
/// to is what keeps the settlement checks pointed at the trade rather than at
/// whatever the node last said.
class PinnedTerms {
  /// The resolved order amount, or null where there was none to pin — a
  /// market-price or range order resolves its sats only after the take.
  final int? amountSats;

  /// The node's fee rate, or null where the info event had not arrived.
  final double? feeRate;

  /// The currency, fiat figure and premium the market quote is priced from.
  final String? fiatCode;
  final int? fiatAmount;
  final double? premium;

  /// When these terms were pinned, so an anchor for a trade long finished can
  /// be pruned.
  final DateTime pinnedAt;

  const PinnedTerms({
    this.amountSats,
    this.feeRate,
    this.fiatCode,
    this.fiatAmount,
    this.premium,
    required this.pinnedAt,
  });

  Map<String, dynamic> toJson() => {
        if (amountSats != null) 'amount_sats': amountSats,
        if (feeRate != null) 'fee_rate': feeRate,
        if (fiatCode != null) 'fiat_code': fiatCode,
        if (fiatAmount != null) 'fiat_amount': fiatAmount,
        if (premium != null) 'premium': premium,
        'pinned_at': pinnedAt.millisecondsSinceEpoch,
      };

  /// Null for a record that cannot be read back, so a corrupt entry is the
  /// same as no entry rather than a half-populated anchor.
  static PinnedTerms? fromJson(Object? json) {
    if (json is! Map) return null;

    final pinnedAt = json['pinned_at'];
    if (pinnedAt is! int) return null;

    final amount = json['amount_sats'];
    final fee = json['fee_rate'];
    final fiatAmount = json['fiat_amount'];
    final premium = json['premium'];

    return PinnedTerms(
      amountSats: amount is int && amount > 0 ? amount : null,
      feeRate: fee is num && fee >= 0 && fee.toDouble().isFinite
          ? fee.toDouble()
          : null,
      fiatCode: json['fiat_code'] is String && (json['fiat_code'] as String).isNotEmpty
          ? json['fiat_code'] as String
          : null,
      fiatAmount: fiatAmount is int && fiatAmount > 0 ? fiatAmount : null,
      premium: premium is num && premium.toDouble().isFinite
          ? premium.toDouble()
          : null,
      pinnedAt: DateTime.fromMillisecondsSinceEpoch(pinnedAt),
    );
  }
}

/// Remembers what each trade committed to, keyed by its trade key.
///
/// The session row in Sembast already carries these figures, and is not
/// enough on its own. It is written when the daemon acknowledges the trade,
/// which is after the commitment has been published — a crash or a response
/// timeout in between leaves the remote trade standing and the anchors gone.
/// Worse, a restore clears the session store outright and rebuilds every
/// session from the node's own data, so switching nodes and back returned a
/// committed trade to whatever terms the node currently advertises.
///
/// This store is the part that survives both. It is written before the
/// commitment goes out and lives outside the session store, so
/// `SessionStorage.deleteAll` does not take it, and it is keyed by the trade
/// key because that is the one identifier that spans the whole lifecycle: it
/// exists before the order id does, it is what the commitment is signed with,
/// and restore re-derives it from the key index.
class SettlementTermsStore {
  static const String _prefsKey = 'settlement_pinned_terms';

  /// How long an anchor is kept. Well past any trade's life, short enough
  /// that the map does not grow without bound.
  static const Duration retention = Duration(days: 90);

  final SharedPreferencesAsync _prefs;

  /// Trade key pubkey -> the terms that trade committed to. Authoritative
  /// once [init] has run; the persisted copy mirrors it.
  Map<String, PinnedTerms> _terms = {};

  bool _initialized = false;

  /// Tail of the write chain, so writes land in call order.
  Future<void> _writes = Future<void>.value();

  SettlementTermsStore(this._prefs);

  /// Completes when every write queued so far has finished. [pin] returns only
  /// once its own write has landed, so callers that must be durable before
  /// publishing simply await it.
  Future<void> get pendingWrites => _writes;

  /// Loads the persisted anchors. Must run before the first [termsFor], or a
  /// restore would read an empty map and reconstruct committed trades as
  /// legacy.
  Future<void> init() async {
    if (_initialized) return;
    try {
      final raw = await _prefs.getString(_prefsKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          final loaded = <String, PinnedTerms>{};
          decoded.forEach((key, value) {
            if (key is! String) return;
            final terms = PinnedTerms.fromJson(value);
            if (terms != null) loaded[key] = terms;
          });
          _terms = loaded;
        }
      }
    } catch (e) {
      logger.e('Failed to load pinned settlement terms: $e');
      _terms = {};
    }
    _initialized = true;
    _prune();
  }

  /// The terms [tradeKeyPublic] committed to, or null if it never pinned any.
  ///
  /// Null is what a session written before pinning existed looks like, which
  /// is the same thing the caller does with it: leave the trade behaving as it
  /// did rather than applying a check it never agreed to.
  PinnedTerms? termsFor(String tradeKeyPublic) => _terms[tradeKeyPublic];

  /// Records what [tradeKeyPublic] is committing to, and returns once the
  /// record is durable.
  ///
  /// Call this before the commitment is published. An anchor already held for
  /// the trade key is kept: a retake must not overwrite the terms the first
  /// commitment pinned.
  Future<void> pin(
    String tradeKeyPublic, {
    int? amountSats,
    double? feeRate,
    String? fiatCode,
    int? fiatAmount,
    double? premium,
    DateTime? pinnedAt,
  }) {
    if (_terms.containsKey(tradeKeyPublic)) return Future<void>.value();

    _terms[tradeKeyPublic] = PinnedTerms(
      amountSats: amountSats,
      feeRate: feeRate,
      fiatCode: fiatCode,
      fiatAmount: fiatAmount,
      premium: premium,
      pinnedAt: pinnedAt ?? DateTime.now(),
    );
    return _flush();
  }

  /// Drops the anchor for [tradeKeyPublic]. For a session the user deleted;
  /// a finished trade is left to [retention].
  Future<void> forget(String tradeKeyPublic) {
    if (_terms.remove(tradeKeyPublic) == null) return Future<void>.value();
    return _flush();
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(retention);
    final before = _terms.length;
    _terms.removeWhere((_, terms) => terms.pinnedAt.isBefore(cutoff));
    if (_terms.length != before) _flush();
  }

  /// Appends the write to the chain. `SharedPreferencesAsync` keeps no Dart
  /// cache and completes concurrent calls in whatever order the platform
  /// picks, so without the chain an older snapshot could land after a newer
  /// one. Failures are logged and swallowed: one bad write must not poison
  /// every later one, and memory stays authoritative for this run.
  Future<void> _flush() {
    final snapshot = jsonEncode(
      _terms.map((key, value) => MapEntry(key, value.toJson())),
    );
    final queued = _writes
        .then((_) => _prefs.setString(_prefsKey, snapshot))
        .catchError(
          (Object e) => logger.e('Failed to persist pinned settlement terms: $e'),
        );
    _writes = queued;
    return queued;
  }
}

final settlementTermsStoreProvider = Provider<SettlementTermsStore>(
  (ref) => SettlementTermsStore(ref.read(sharedPreferencesProvider)),
);
