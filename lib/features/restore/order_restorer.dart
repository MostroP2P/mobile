import 'package:logger/logger.dart';

class OrderRestorer {
  final Logger _logger = Logger();

  List<String> extractOrderIds({
    required List<dynamic>? restoreOrders,
    required List<dynamic>? restoreDisputes,
  }) {
    final orderIds = <String>[];

    if (restoreOrders != null) {
      for (final order in restoreOrders) {
        final orderId = order['order_id'] as String?;
        if (orderId != null) {
          orderIds.add(orderId);
        }
      }
    }

    if (restoreDisputes != null) {
      for (final dispute in restoreDisputes) {
        final orderId = dispute['order_id'] as String?;
        if (orderId != null) {
          orderIds.add(orderId);
        }
      }
    }

    if (orderIds.isNotEmpty) {
      _logger.d('Extracted ${orderIds.length} order IDs for details request');
    }

    return orderIds;
  }

  void logOrderDetails(List<dynamic>? orderDetails) {
    if (orderDetails == null || orderDetails.isEmpty) {
      _logger.w('No order details received');
      return;
    }

    _logger.i('Received details for ${orderDetails.length} orders');
    for (final order in orderDetails) {
      _logger.d('Order: ${order['id']} - Status: ${order['status']}');
    }
  }
}
