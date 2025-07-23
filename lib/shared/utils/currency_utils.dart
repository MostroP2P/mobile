import 'package:mostro_mobile/data/models/currency.dart';

class CurrencyUtils {
  static String getFlagEmoji(String countryCode) {
    return countryCode
        .toUpperCase()
        .split('')
        .map((char) => String.fromCharCode(
            0x1F1E6 + char.codeUnitAt(0) - 'A'.codeUnitAt(0)))
        .join();
  }

  static String? getFlagFromCurrency(String currencyCode) {
    String? countryCode = currencyCode.toUpperCase().substring(0, 2);
    return getFlagEmoji(countryCode);
  }

  /// Get flag emoji from currency data - uses correct emoji from fiat.json
  static String getFlagFromCurrencyData(String currencyCode, Map<String, Currency>? currencyData) {
    if (currencyData == null) {
      // Fallback to old method if data not available
      return getFlagFromCurrency(currencyCode) ?? '🏳️';
    }
    
    final currency = currencyData[currencyCode.toUpperCase()];
    if (currency != null && currency.emoji.isNotEmpty) {
      return currency.emoji;
    }
    
    // Fallback to generic flag if currency not found
    return '🏳️';
  }
}
