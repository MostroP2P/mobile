import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/nostr_exchange_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  // Select: recreating this service on unrelated settings writes dropped its
  // 1 h rate cache and refetched every watched currency over the relays.
  final mostroPubkey =
      ref.watch(settingsProvider.select((s) => s.mostroPublicKey));
  return NostrExchangeService(
    nostrService: nostrService,
    mostroPubkey: mostroPubkey,
  );
});

final exchangeRateProvider =
    StateNotifierProvider.family<
      ExchangeRateNotifier,
      AsyncValue<double>,
      String
    >((ref, currency) {
      final exchangeService = ref.watch(exchangeServiceProvider);
      final notifier = ExchangeRateNotifier(exchangeService);
      notifier.fetchExchangeRate(currency);
      return notifier;
    });

final currencyCodesProvider = FutureProvider<Map<String, Currency>>((
  ref,
) async {
  final raw = await rootBundle.loadString('assets/data/fiat.json');
  final jsonMap = json.decode(raw) as Map<String, dynamic>;
  final Map<String, Currency> currencies = jsonMap.map(
    (key, value) => MapEntry(key, Currency.fromJson(value)),
  );
  currencies.removeWhere((k, v) => !v.price);
  return currencies;
});

final selectedFiatCodeProvider = StateProvider<String?>((ref) {
  // Initialize with null - will be set from settings when needed
  return null;
});
