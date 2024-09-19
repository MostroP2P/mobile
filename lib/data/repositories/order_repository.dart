import '../../features/home/data/models/order_model.dart';

class OrderRepository {
  Future<List<OrderModel>> getOrders() async {
    // TODO: Implement actual nostr call to get orders
    await Future.delayed(
        const Duration(seconds: 1)); // Simulating network delay
    return [
      OrderModel(
        id: '1',
        type: 'buy',
        user: 'anon 5/5',
        rating: 5.0,
        ratingCount: 2,
        amount: 1200000,
        currency: 'sats',
        fiatAmount: 31.08,
        fiatCurrency: 'VES',
        paymentMethod: 'Wire transfer',
        timeAgo: '1 week ago',
        premium: '+3%',
      ),
      OrderModel(
        id: '2',
        type: 'sell',
        user: 'anon 3.9/5',
        rating: 3.9,
        ratingCount: 5,
        amount: 390000,
        currency: 'sats',
        fiatAmount: 3231,
        fiatCurrency: 'MXN',
        paymentMethod: 'Transferencia bancaria',
        timeAgo: '2 weeks ago',
        premium: '+0%',
      ),
      OrderModel(
        id: '3',
        type: 'sell',
        user: 'Pedro9734 5/5',
        rating: 5.0,
        ratingCount: 19,
        amount: 390000,
        currency: 'sats',
        fiatAmount: 3483,
        fiatCurrency: 'MXN',
        paymentMethod: 'Revolut',
        timeAgo: '2 weeks ago',
        premium: '+1%',
      ),
    ];
  }
}
