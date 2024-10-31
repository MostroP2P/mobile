import 'exchange_service.dart';

class YadioExchangeService extends ExchangeService {
  YadioExchangeService() : super('https://api.yadio.io/');

  @override
  Future<double> getExchangeRate(
    String fromCurrency,
    String toCurrency,
  ) async {
    final endpoint = 'rate/$fromCurrency/$toCurrency';
    final data = await getRequest(endpoint);

    if (data.containsKey('rate')) {
      return (data['rate'] as num).toDouble();
    } else {
      throw Exception('Exchange rate not found in response');
    }
  }

  @override
  Future<Map<String, String>> getCurrencyCodes() async {
    final endpoint = 'currencies';
    final data = await getRequest(endpoint);
    
    return data.map((key, value) => MapEntry(key, value.toString()));
    
  }
}
