import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/exchange_service.dart';
import 'package:mostro_mobile/services/yadio_exchange_service.dart';

final exchangeServiceProvider = Provider<ExchangeService>((ref) {
  return YadioExchangeService();
});

final exchangeRateProvider = StateNotifierProvider.family<ExchangeRateNotifier, AsyncValue<double>, String>((ref, currency) {
  final exchangeService = ref.read(exchangeServiceProvider);
  final notifier = ExchangeRateNotifier(exchangeService);
  notifier.fetchExchangeRate(currency);
  return notifier;
});

final currencyCodesProvider = FutureProvider<Map<String, String>>((ref) async {
  final exchangeService = ref.read(exchangeServiceProvider);
  
  return await exchangeService.getCurrencyCodes();
});

final selectedFiatCodeProvider = StateProvider<String?>((ref) => null);
