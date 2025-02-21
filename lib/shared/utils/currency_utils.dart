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
}
