import 'exchange_service.dart';

class YadioExchangeService extends ExchangeService {
  YadioExchangeService() : super('https://api.yadio.io/');

  @override
  Future<double> getExchangeRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    if (fromCurrency.isEmpty || toCurrency.isEmpty) {
      throw ArgumentError('Currency codes cannot be empty');
    }

    final endpoint = 'rate/$fromCurrency/$toCurrency';
    try {
      final data = await getRequest(endpoint);

      final rate = data['rate'];
      if (rate == null) {
        throw Exception('Rate not found for $fromCurrency to $toCurrency');
      }

      if (rate is! num) {
        throw Exception('Invalid rate format received from API');
      }
      return rate.toDouble();
    } catch (e) {
      throw Exception('Failed to fetch exchange rate: $e');
    }
  }

  @override
  Future<Map<String, String>> getCurrencyCodes() async {
    final endpoint = 'currencies';
    try {
      final data = await getRequest(endpoint);
      return Map.fromEntries(
        data.entries.where((entry) => entry.key != 'BTC')
        .map((entry) {
          return MapEntry(entry.key, entry.value?.toString() ?? '');
        }),
      );
    } catch (e) {
      throw Exception('Failed to fetch currency codes: $e');
    }
  }
}
