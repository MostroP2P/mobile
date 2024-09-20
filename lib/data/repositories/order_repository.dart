import 'package:dart_nostr/dart_nostr.dart';
import '../../features/home/data/models/order_model.dart';
import 'package:convert/convert.dart';

class OrderRepository {
  Future<List<OrderModel>> getOrdersFromNostr() async {
    List<OrderModel> orders = [];

    try {
      // Crear el filtro para obtener eventos con kind 38383 (órdenes)
      const filter = NostrFilter(
        kinds: [38383],
        // Aquí puedes agregar más filtros como autor o estado (s) si es necesario
      );

      // Suscribirse a eventos que coincidan con el filtro
      final subscription = Nostr.instance.relaysService.startEventsSubscription(
        request: NostrRequest(filters: const [filter]),
      );

      await for (final event in subscription.stream) {
        // Procesar cada evento recibido
        final tags = event.tags ??
            []; // Manejar caso nulo con un valor por defecto vacío
        final order = OrderModel(
          id: event.id ?? '', // Manejar caso nulo de 'id'
          type: _getTagValue(tags, 'k'), // 'sell' o 'buy'
          user: event.pubkey ?? '', // Manejar caso nulo de 'pubkey'
          rating:
              5.0, // Valor simulado, puedes actualizarlo según sea necesario
          ratingCount: 1, // Simulado
          amount: int.parse(_getTagValue(tags, 'amt')),
          currency: 'sats',
          fiatAmount: double.parse(_getTagValue(tags, 'fa')),
          fiatCurrency: _getTagValue(tags, 'f'),
          paymentMethod: _getTagValue(tags, 'pm'),
          timeAgo: 'Pending', // Simulación
          premium: _getTagValue(tags, 'premium'),
          satsAmount: double.parse(_getTagValue(tags, 'amt')),
          sellerName: 'Nostr User', // Simulado
          sellerRating: 5.0, // Simulado
          sellerReviewCount: 10, // Simulado
          sellerAvatar: '', // Simulado
          exchangeRate: 40000.0, // Simulado
          buyerSatsAmount: 0, // Simulado
          buyerFiatAmount: 0, // Simulado
        );

        orders.add(order);
      }
    } catch (e) {
      print('Error al obtener órdenes: $e');
    }

    return orders;
  }

  // Función para extraer el valor de una etiqueta
  String _getTagValue(List<List<String>> tags, String key) {
    for (var tag in tags) {
      if (tag.isNotEmpty && tag[0] == key) {
        return tag[1];
      }
    }
    return '';
  }
}
