import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/currency.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/yadio_exchange_service.dart';

final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  return YadioExchangeService();
});

final exchangeRateProvider = StateNotifierProvider.family<ExchangeRateNotifier,
    AsyncValue<double>, String>((ref, currency) {
  final exchangeService = ref.read(exchangeServiceProvider);
  final notifier = ExchangeRateNotifier(exchangeService);
  notifier.fetchExchangeRate(currency);
  return notifier;
});

final currencyCodesProvider =
    FutureProvider<Map<String, Currency>>((ref) async {
  final raw = await rootBundle.loadString('assets/data/fiat.json');
  final jsonMap = json.decode(raw) as Map<String, dynamic>;
  final Map<String, Currency> currencies =
      jsonMap.map((key, value) => MapEntry(key, Currency.fromJson(value)));
  currencies.removeWhere((k, v) => !v.price);
  return currencies;
});

final selectedFiatCodeProvider = StateProvider<String?>((ref) => null);

