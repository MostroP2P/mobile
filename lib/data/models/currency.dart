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
  }) {
    if (symbol.isEmpty) {
      throw ArgumentError('Currency symbol cannot be empty');
    }
    if (name.isEmpty) {
      throw ArgumentError('Currency name cannot be empty');
    }
    if (code.isEmpty) {
      throw ArgumentError('Currency code cannot be empty');
    }
    if (decimalDigits < 0) {
      throw ArgumentError('Decimal digits cannot be negative: $decimalDigits');
    }
  }

  factory Currency.fromJson(Map<String, dynamic> json) {
    try {
      // Validate required fields
      final requiredFields = ['symbol', 'name', 'symbol_native', 'code', 'emoji', 'decimal_digits', 'name_plural'];
      for (final field in requiredFields) {
        if (!json.containsKey(field) || json[field] == null) {
          throw FormatException('Missing required field: $field');
        }
      }

      // Parse and validate decimal_digits
      final decimalDigitsValue = json['decimal_digits'];
      int decimalDigits;
      if (decimalDigitsValue is int) {
        decimalDigits = decimalDigitsValue;
      } else if (decimalDigitsValue is String) {
        decimalDigits = int.tryParse(decimalDigitsValue) ??
            (throw FormatException('Invalid decimal_digits format: $decimalDigitsValue'));
      } else {
        throw FormatException('Invalid decimal_digits type: ${decimalDigitsValue.runtimeType}');
      }

      // Parse price field
      final priceValue = json['price'];
      bool price;
      if (priceValue is bool) {
        price = priceValue;
      } else if (priceValue is String) {
        price = priceValue.toLowerCase() == 'true';
      } else if (priceValue == null) {
        price = false;
      } else {
        throw FormatException('Invalid price type: ${priceValue.runtimeType}');
      }

      return Currency(
        symbol: json['symbol'].toString(),
        name: json['name'].toString(),
        symbolNative: json['symbol_native'].toString(),
        code: json['code'].toString(),
        emoji: json['emoji'].toString(),
        decimalDigits: decimalDigits,
        namePlural: json['name_plural'].toString(),
        price: price,
        locale: json['locale']?.toString(),
      );
    } catch (e) {
      throw FormatException('Failed to parse Currency from JSON: $e');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'symbol': symbol,
      'name': name,
      'symbol_native': symbolNative,
      'code': code,
      'emoji': emoji,
      'decimal_digits': decimalDigits,
      'name_plural': namePlural,
      'price': price,
      if (locale != null) 'locale': locale,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Currency &&
        other.symbol == symbol &&
        other.name == name &&
        other.symbolNative == symbolNative &&
        other.decimalDigits == decimalDigits &&
        other.code == code &&
        other.emoji == emoji &&
        other.namePlural == namePlural &&
        other.price == price &&
        other.locale == locale;
  }

  @override
  int get hashCode {
    return Object.hash(
      symbol,
      name,
      symbolNative,
      decimalDigits,
      code,
      emoji,
      namePlural,
      price,
      locale,
    );
  }

  @override
  String toString() {
    return 'Currency(symbol: $symbol, name: $name, code: $code, price: $price)';
  }
}
