import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/services/yadio_exchange_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Exchange rate event kind (NIP-33 addressable event).
const int _exchangeRatesEventKind = 30078;

/// NIP-33 d-tag identifier used by Mostro daemon.
const String _exchangeRatesDTag = 'mostro-rates';

/// Key used to persist the latest rates JSON in SharedPreferences.
const String _cacheKey = 'exchange_rates_cache';

/// Key used to persist the cache timestamp (milliseconds since epoch).
const String _cacheTimestampKey = 'exchange_rates_cache_ts';

/// Maximum age of cached rates before they are considered stale (1 hour).
const Duration _maxCacheAge = Duration(hours: 1);

/// Exchange service that fetches rates from Nostr (NIP-33 kind 30078),
/// falling back to Yadio HTTP API, then to a local SharedPreferences cache.
///
/// The service verifies that events are signed by the connected Mostro
/// instance pubkey to prevent price manipulation attacks.
class NostrExchangeService extends ExchangeService {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final YadioExchangeService _yadioFallback;

  /// In-memory cache of all BTC→fiat rates from the last successful fetch.
  /// Keys are uppercase currency codes ("USD", "EUR", …), values are the
  /// price of 1 BTC in that currency.
  Map<String, double>? _cachedRates;

  NostrExchangeService({
    required NostrService nostrService,
    required String mostroPubkey,
  }) : _nostrService = nostrService,
       _mostroPubkey = mostroPubkey,
       _yadioFallback = YadioExchangeService(),
       super('https://api.yadio.io/');

  // ── ExchangeService interface ──────────────────────────────────────

  @override
  Future<double> getExchangeRate(String fromCurrency, String toCurrency) async {
    if (fromCurrency.isEmpty || toCurrency.isEmpty) {
      throw ArgumentError('Currency codes cannot be empty');
    }

    // If we already have rates in memory, return immediately.
    final cached = _cachedRates;
    if (cached != null && cached.containsKey(fromCurrency)) {
      return cached[fromCurrency]!;
    }

    // Otherwise fetch a full set and extract the requested pair.
    await _refreshRates();

    final rate = _cachedRates?[fromCurrency];
    if (rate == null) {
      throw Exception('Rate not found for $fromCurrency');
    }
    return rate;
  }

  @override
  Future<Map<String, String>> getCurrencyCodes() {
    // Currency codes come from the bundled asset, not from rates.
    // Delegate to Yadio only as a last resort; the provider already
    // loads from assets/data/fiat.json (see currencyCodesProvider).
    return _yadioFallback.getCurrencyCodes();
  }

  // ── Internal ───────────────────────────────────────────────────────

  /// Try each source in order: Nostr → HTTP → SharedPreferences cache.
  Future<void> _refreshRates() async {
    // 1. Nostr
    try {
      final rates = await _fetchFromNostr().timeout(
        const Duration(seconds: 10),
      );
      _cachedRates = rates;
      await _persistToCache(rates);
      return;
    } catch (e) {
      logger.w('Nostr exchange rates failed: $e');
    }

    // 2. Yadio HTTP
    try {
      final rates = await _fetchFromYadio().timeout(
        const Duration(seconds: 30),
      );
      _cachedRates = rates;
      await _persistToCache(rates);
      return;
    } catch (e) {
      logger.w('Yadio HTTP exchange rates failed: $e');
    }

    // 3. SharedPreferences cache
    final cached = await _loadFromCache();
    if (cached != null) {
      logger.i('Using cached exchange rates');
      _cachedRates = cached;
      return;
    }

    throw Exception(
      'Failed to fetch exchange rates from all sources (Nostr, HTTP, cache)',
    );
  }

  /// Fetch rates from Nostr by querying for the latest kind 30078 event
  /// signed by the connected Mostro instance.
  Future<Map<String, double>> _fetchFromNostr() async {
    final filter = NostrFilter(
      kinds: [_exchangeRatesEventKind],
      authors: [_mostroPubkey],
      limit: 1,
      additionalFilters: {
        '#d': [_exchangeRatesDTag],
      },
    );

    final events = await _nostrService.fetchEvents(filter);

    if (events.isEmpty) {
      throw Exception('No exchange rate event found on relays');
    }

    // Take the most recent event.
    final event = events.reduce(
      (a, b) => (a.createdAt?.compareTo(b.createdAt ?? '') ?? 0) >= 0 ? a : b,
    );

    // CRITICAL: verify pubkey (defense-in-depth — filter already limits
    // authors, but relays are untrusted).
    if (event.pubkey != _mostroPubkey) {
      throw Exception(
        'Exchange rate event pubkey mismatch: '
        'expected $_mostroPubkey, got ${event.pubkey}',
      );
    }

    return _parseRatesContent(event.content ?? '');
  }

  /// Fetch all BTC rates from Yadio HTTP API and return them as a map.
  Future<Map<String, double>> _fetchFromYadio() async {
    final data = await getRequest('exrates/BTC');

    final btcRates = data['BTC'];
    if (btcRates is! Map) {
      throw Exception('Unexpected Yadio response format');
    }

    final rates = <String, double>{};
    for (final entry in btcRates.entries) {
      if (entry.key == 'BTC') continue; // skip BTC→BTC = 1
      final value = entry.value;
      if (value is num) {
        rates[entry.key as String] = value.toDouble();
      }
    }
    return rates;
  }

  /// Parse the JSON content of a Nostr exchange rates event.
  ///
  /// Expected format: `{"BTC": {"USD": 50000.0, "EUR": 45000.0, ...}}`
  static Map<String, double> _parseRatesContent(String content) {
    final decoded = jsonDecode(content);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object');
    }

    final btcRates = decoded['BTC'];
    if (btcRates is! Map<String, dynamic>) {
      throw const FormatException('Missing or invalid "BTC" key');
    }

    final rates = <String, double>{};
    for (final entry in btcRates.entries) {
      if (entry.key == 'BTC') continue;
      final value = entry.value;
      if (value is num) {
        rates[entry.key] = value.toDouble();
      }
    }

    if (rates.isEmpty) {
      throw const FormatException('No valid rates found');
    }

    return rates;
  }

  // ── SharedPreferences cache ────────────────────────────────────────

  Future<void> _persistToCache(Map<String, double> rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(rates));
      await prefs.setInt(
        _cacheTimestampKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      logger.w('Failed to cache exchange rates: $e');
    }
  }

  Future<Map<String, double>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTimestampKey);

      if (json == null || ts == null) return null;

      // Check staleness
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
      if (age > _maxCacheAge) {
        logger.w('Cached exchange rates too old (${age.inMinutes} min)');
        return null;
      }

      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;

      return decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
    } catch (e) {
      logger.w('Failed to load cached exchange rates: $e');
      return null;
    }
  }
}
