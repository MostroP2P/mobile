import 'package:dart_nostr/dart_nostr.dart';
import '../models/order_model.dart';
import '../../services/nostr_service.dart';

class OrderRepository {
  final NostrService nostrService;

  OrderRepository(this.nostrService);

  Future<List<OrderModel>> getOrdersFromNostr() async {
    List<OrderModel> orders = [];

    try {
      const filter = NostrFilter(kinds: [38383]);
      final eventStream = nostrService.subscribeToEvents(filter);

      await for (final event in eventStream) {
        final order = _parseEventToOrder(event);
        if (order != null) {
          orders.add(order);
          print('Order added: ${order.id}');
        }
      }
    } catch (e) {
      print('Error al obtener órdenes: $e');
    }

    print('Total orders fetched: ${orders.length}');
    return orders;
  }

  OrderModel? _parseEventToOrder(NostrEvent event) {
    try {
      final tags = Map.fromEntries(event.tags!.map((t) => MapEntry(t[0], t.sublist(1))));

      final id = tags['d']?.first ?? '';
      final type = tags['k']?.first.toLowerCase() ?? '';
      final fiatCurrency = tags['f']?.first ?? '';
      final status = tags['s']?.first ?? '';
      final amount = int.tryParse(tags['amt']?.first ?? '0') ?? 0;
      final fiatAmount = double.tryParse(tags['fa']?.first ?? '0') ?? 0.0;
      final paymentMethod = tags['pm']?.join(', ') ?? '';
      final premium = tags['premium']?.first ?? '0';

      return OrderModel(
        id: id,
        type: type,
        user: event.pubkey ?? '',
        rating: 0.0,
        ratingCount: 0,
        amount: amount,
        currency: 'sats',
        fiatAmount: fiatAmount,
        fiatCurrency: fiatCurrency,
        paymentMethod: paymentMethod,
        timeAgo: 'Recently',
        premium: premium,
        satsAmount: amount.toDouble(),
        sellerName: 'Unknown',
        sellerRating: 0.0,
        sellerReviewCount: 0,
        sellerAvatar: '',
        exchangeRate: amount > 0 ? fiatAmount / amount : 0,
        buyerSatsAmount: 0,
        buyerFiatAmount: 0,
        status: status
      );
    } catch (e) {
      print('Error parsing event to order: $e');
      return null;
    }
  }
}
