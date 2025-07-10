class MasterKeyNotFoundException implements Exception {
  final String message;
  MasterKeyNotFoundException(this.message);

  @override
  String toString() => 'MasterKeyNotFoundException: $message';
}

class TradeKeyDerivationException implements Exception {
  final String message;
  TradeKeyDerivationException(this.message);

  @override
  String toString() => 'TradeKeyDerivationException: $message';
}

class InvalidTradeKeyIndexException implements Exception {
  final String message;
  InvalidTradeKeyIndexException(this.message);

  @override
  String toString() => 'InvalidTradeKeyIndexException: $message';
}
