import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart'; // Used for star color definition
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/nostr_event.dart';
import 'package:mostro_mobile/shared/providers/time_provider.dart';
import 'package:mostro_mobile/shared/utils/currency_utils.dart';

class OrderListItem extends ConsumerWidget {
  final NostrEvent order;

  const OrderListItem({super.key, required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(timeProvider);

    // Determinar si el premium es positivo o negativo para el color
    final premiumValue =
        order.premium != null ? double.tryParse(order.premium!) ?? 0.0 : 0.0;
    final isPremiumPositive = premiumValue >= 0;
    final premiumColor = isPremiumPositive ? Colors.green : Colors.red;
    final premiumText = premiumValue == 0
        ? "(0%)"
        : isPremiumPositive
            ? "(+$premiumValue%)"
            : "($premiumValue%)";

    return GestureDetector(
      onTap: () {
        order.orderType == OrderType.buy
            ? context.push('/take_buy/${order.orderId}')
            : context.push('/take_sell/${order.orderId}');
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(
              0xFF1E2230), // Color más oscuro exacto como en la referencia
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Primera fila: Etiqueta "SELLING" y timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Etiqueta SELLING/BUYING
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(
                          0xFF171A23), // Fondo más oscuro para la etiqueta
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      order.orderType == OrderType.buy ? 'BUYING' : 'SELLING',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),

                  // Timestamp
                  Text(
                    order.expiration ?? '9 hours ago',
                    style: const TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Segunda fila: Monto y moneda con bandera y porcentaje
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Monto grande
                  Text(
                    order.fiatAmount.toString(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.1, // Reduce el espacio vertical
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Código de moneda y bandera
                  Text(
                    '${order.currency ?? "CUP"} ',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    () {
                      final String currencyCode = order.currency ?? 'CUP';
                      return CurrencyUtils.getFlagFromCurrency(currencyCode) ?? '';
                    }(),
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(width: 4),

                  // Porcentaje con color
                  Text(
                    premiumText,
                    style: TextStyle(
                      fontSize: 16,
                      color: premiumColor,
                    ),
                  ),
                ],
              ),
            ),

            // Tercera fila: Método de pago
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF171A23), // Fondo más oscuro exacto
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  // Emoji de bandera para método de pago
                  const Text(
                    '🇪🇸 ', // Usar un emoji de bandera por defecto
                    style: TextStyle(fontSize: 16),
                  ),
                  Text(
                    order.paymentMethods.isNotEmpty
                        ? order.paymentMethods[0]
                        : 'tm',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Cuarta fila: Calificación con estrellas
            _buildRatingRow(order),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingRow(NostrEvent order) {
    // Supongamos que la calificación está en un rango de 0 a 5
    final rating = order.rating?.totalRating ?? 0.0;
    final trades = order.rating?.totalReviews ?? 0;
    final daysOld = 50; // Valor por defecto si no tenemos esta información

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF171A23), // Fondo más oscuro exacto
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Calificación con número y estrellas
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 6),
              // Estrellas - usando imágenes más precisas
              Row(
                children: List.generate(5, (index) {
                  Color starColor = Colors.amber; // Color de las estrellas
                  if (index < rating.floor()) {
                    // Estrella completa
                    return Icon(Icons.star, color: starColor, size: 14);
                  } else if (index == rating.floor() && rating % 1 > 0) {
                    // Estrella parcial
                    return Icon(Icons.star_half, color: starColor, size: 14);
                  } else {
                    // Estrella vacía
                    return Icon(Icons.star_border, color: starColor, size: 14);
                  }
                }),
              ),
            ],
          ),

          // Número de trades y días
          Text(
            '$trades trades • $daysOld days old',
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
