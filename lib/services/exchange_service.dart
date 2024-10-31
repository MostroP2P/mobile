import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

class ExchangeRateNotifier extends StateNotifier<AsyncValue<double>> {
  final ExchangeService exchangeService;

  ExchangeRateNotifier(this.exchangeService)
      : super(const AsyncValue.loading());

  Future<void> fetchExchangeRate(String currency) async {
    try {
      state = const AsyncValue.loading();
      final rate = await exchangeService.getExchangeRate(currency, 'BTC');
      state = AsyncValue.data(rate);
    } catch (error) {
      state = AsyncValue.error(error, StackTrace.current);
    }
  }
}

abstract class ExchangeService {
  final String baseUrl;

  ExchangeService(this.baseUrl);

  Future<double> getExchangeRate(
    String fromCurrency,
    String toCurrency,
  );

  Future<Map<String, dynamic>> getRequest(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load data: ${response.statusCode}');
    }
  }

  Future<Map<String, String>> getCurrencyCodes();
}
