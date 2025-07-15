class Currency {
  final String symbol;
  final String name;
  final String symbolNative;
  final int decimalDigits;
  final String code;
  final String emoji;
  final String namePlural;
  final bool price;
  String? locale;

  Currency({
    required this.symbol,
    required this.name,
    required this.symbolNative,
    required this.code,
    required this.emoji,
    required this.decimalDigits,
    required this.namePlural,
    required this.price,
    this.locale,
  });

  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      symbol: json['symbol'],
      name: json['name'],
      symbolNative: json['symbol_native'],
      code: json['code'],
      emoji: json['emoji'],
      decimalDigits: json['decimal_digits'],
      namePlural: json['name_plural'],
      price: json['price'] ?? false,
      locale: json['locale'],
    );
  }
}
