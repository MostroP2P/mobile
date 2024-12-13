import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final Duration timeout;
  final Map<String, String> defaultHeaders;

  ExchangeService(
    this.baseUrl, {
    this.timeout = const Duration(seconds: 30),
    this.defaultHeaders = const {'Accept': 'application/json'},
  }) {
    if (baseUrl.isEmpty) {
      throw ArgumentError('baseUrl cannot be empty');
    }
    if (!baseUrl.startsWith('http')) {
      throw ArgumentError('baseUrl must start with http:// or https://');
    }
  }

  Future<double> getExchangeRate(
    String fromCurrency,
    String toCurrency,
  );

  Future<Map<String, dynamic>> getRequest(String endpoint) async {
    final url = Uri.parse('$baseUrl$endpoint');
    try {
      final response = await http
          .get(url, headers: defaultHeaders)
          .timeout(timeout);

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      
      throw HttpException(
        'Failed to load data: ${response.statusCode}',
        uri: url,
      );
    } on TimeoutException {
      throw HttpException('Request timed out', uri: url);
    } on FormatException catch (e) {
      throw HttpException('Invalid response format: ${e.message}', uri: url);
    } catch (e) {
      throw HttpException('Request failed: $e', uri: url);
    }
  }

  Future<Map<String, String>> getCurrencyCodes();
}