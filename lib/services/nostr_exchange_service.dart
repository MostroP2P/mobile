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
/// The service verifies that events originate from the connected Mostro
/// instance by comparing event.pubkey to settings.mostroPublicKey.
class NostrExchangeService extends ExchangeService {
  final NostrService _nostrService;
  final String _mostroPubkey;
  final YadioExchangeService _yadioFallback;

  /// In-memory cache of all BTC→fiat rates from the last successful fetch.
  /// Keys are uppercase currency codes ("USD", "EUR", …), values are the
  /// price of 1 BTC in that currency.
  Map<String, double>? _cachedRates;

  /// Timestamp when [_cachedRates] was last populated.
  /// Used to enforce the same 1-hour freshness as SharedPreferences.
  DateTime? _cachedRatesFetchedAt;

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

    // If we already have fresh rates in memory, return immediately.
    final cached = _cachedRates;
    final fetchedAt = _cachedRatesFetchedAt;
    if (cached != null &&
        fetchedAt != null &&
        DateTime.now().difference(fetchedAt) < _maxCacheAge &&
        cached.containsKey(fromCurrency)) {
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
      _cachedRatesFetchedAt = DateTime.now();
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
      _cachedRatesFetchedAt = DateTime.now();
      await _persistToCache(rates);
      return;
    } catch (e) {
      logger.w('Yadio HTTP exchange rates failed: $e');
    }

    // 3. SharedPreferences cache
    final result = await _loadFromCache();
    if (result != null) {
      logger.i('Using cached exchange rates');
      _cachedRates = result.rates;
      // Preserve the original persisted timestamp, not DateTime.now()
      _cachedRatesFetchedAt = result.fetchedAt;
      return;
    }

    // All sources failed — clear stale in-memory cache
    _cachedRates = null;
    _cachedRatesFetchedAt = null;

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

    // Filter events to only include those with correct kind and d-tag.
    // Defense-in-depth: relays may return events that don't match the filter.
    final validEvents = events.where((event) {
      // Verify kind
      if (event.kind != _exchangeRatesEventKind) return false;

      // Verify d-tag
      final tags = event.tags;
      if (tags == null) return false;
      final hasDTag = tags.any(
        (tag) =>
            tag.length >= 2 && tag[0] == 'd' && tag[1] == _exchangeRatesDTag,
      );
      if (!hasDTag) return false;

      // Verify pubkey
      if (event.pubkey != _mostroPubkey) return false;

      return true;
    }).toList();

    if (validEvents.isEmpty) {
      throw Exception(
        'No valid exchange rate event found (kind=$_exchangeRatesEventKind, '
        'd-tag=$_exchangeRatesDTag, pubkey=$_mostroPubkey)',
      );
    }

    // Take the most recent valid event.
    final event = validEvents.reduce((a, b) {
      final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return aTime.isAfter(bTime) ? a : b;
    });

    return parseRatesContent(event.content ?? '');
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

    if (rates.isEmpty) {
      throw Exception('No usable rates from Yadio response');
    }

    return rates;
  }

  /// Parse the JSON content of a Nostr exchange rates event.
  ///
  /// Expected format: `{"BTC": {"USD": 50000.0, "EUR": 45000.0, ...}}`
  ///
  /// Exposed as public static for testability.
  static Map<String, double> parseRatesContent(String content) {
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

  Future<_CacheResult?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_cacheKey);
      final ts = prefs.getInt(_cacheTimestampKey);

      if (json == null || ts == null) return null;

      final fetchedAt = DateTime.fromMillisecondsSinceEpoch(ts);

      // Check staleness
      final age = DateTime.now().difference(fetchedAt);
      if (age > _maxCacheAge) {
        logger.w('Cached exchange rates too old (${age.inMinutes} min)');
        return null;
      }

      final decoded = jsonDecode(json);
      if (decoded is! Map<String, dynamic>) return null;

      final rates = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
      return _CacheResult(rates: rates, fetchedAt: fetchedAt);
    } catch (e) {
      logger.w('Failed to load cached exchange rates: $e');
      return null;
    }
  }
}

/// Internal helper to bundle cached rates with their original timestamp.
class _CacheResult {
  final Map<String, double> rates;
  final DateTime fetchedAt;

  const _CacheResult({required this.rates, required this.fetchedAt});
}
