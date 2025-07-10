/// Mock server's trade index storage
class MockServerTradeIndex {
  final Map<String, int> userTradeIndices = {};

  /// Validates and updates the trade index for a user.
  bool validateAndUpdateTradeIndex(String userPubKey, int tradeIndex) {
    final lastIndex = userTradeIndices[userPubKey] ?? 0;
    if (tradeIndex > lastIndex) {
      userTradeIndices[userPubKey] = tradeIndex;
      return true;
    }
    return false;
  }
}

bool validateMessageStructure(Map<String, dynamic> message) {
  // Basic validation of required fields
  if (!message.containsKey('order')) return false;

  final order = message['order'];
  if (order == null || order is! Map<String, dynamic>) return false;

  // Check for required fields in 'order'
  final requiredFields = ['version', 'id', 'action', 'payload'];
  for (var field in requiredFields) {
    if (!order.containsKey(field)) return false;
  }

  return true;
}
