import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_theme.dart';
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
    final premiumColor =
        isPremiumPositive ? const Color(0xFF8CC63F) : const Color(0xFFE45A5A);
    final premiumText = premiumValue == 0
        ? "(0%)"
        : isPremiumPositive
            ? "(+$premiumValue%)"
            : "($premiumValue%)";

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1F2C), // Color ligeramente más claro
        borderRadius: BorderRadius.circular(20),
        // Múltiples sombras para el efecto de brillo
        boxShadow: [
          // Sombra principal para profundidad
          BoxShadow(
            color: Colors.black.withOpacity(0.7),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: -3,
          ),
          // Brillo exterior sutil
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 0),
            spreadRadius: 0,
          ),
          // Efecto de brillo en el borde superior
          BoxShadow(
            color: Colors.white.withOpacity(0.08),
            blurRadius: 2,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
          // Efecto de brillo en los bordes laterales
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(1, 0),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.03),
            blurRadius: 3,
            offset: const Offset(-1, 0),
            spreadRadius: 0,
          ),
        ],
        // Borde sutil para acentuar
        border: Border.all(
          color: Colors.white.withOpacity(0.08), // Más brillante
          width: 1.2, // Ligeramente más grueso
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            order.orderType == OrderType.buy
                ? context.push('/take_buy/${order.orderId}')
                : context.push('/take_sell/${order.orderId}');
          },
          highlightColor: Colors.white.withOpacity(0.05),
          splashColor: Colors.white.withOpacity(0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Primera fila: Etiqueta "SELLING" y timestamp
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Etiqueta SELLING/BUYING con más contraste
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF252A3A), // Más claro
                        borderRadius: BorderRadius.circular(14),
                        // Sombra más definida
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                            spreadRadius: -1,
                          ),
                          // Borde superior iluminado
                          BoxShadow(
                            color: Colors.white.withOpacity(0.08),
                            blurRadius: 1,
                            offset: const Offset(0, -1),
                            spreadRadius: 0,
                          ),
                        ],
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    // Monto grande con más contraste
                    Text(
                      order.fiatAmount.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        height: 1.1,
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
                        return CurrencyUtils.getFlagFromCurrency(
                                currencyCode) ??
                            '';
                      }(),
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 4),

                    // Porcentaje con color más vibrante
                    Text(
                      premiumText,
                      style: TextStyle(
                        fontSize: 16,
                        color: premiumColor,
                        fontWeight: FontWeight.w600, // Más bold
                      ),
                    ),
                  ],
                ),
              ),

              // Tercera fila: Método de pago
              Container(
                margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A3A), // Más claro
                  borderRadius: BorderRadius.circular(12),
                  // Sombra interna más pronunciada
                  boxShadow: [
                    // Sombra principal
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: -2,
                    ),
                    // Brillo sutil en la parte superior
                    BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Emoji para el método de pago
                    Text(
                      order.currency == 'VES' ||
                              order.currency == 'ARS' ||
                              order.currency == 'EUR'
                          ? '🇪🇸 '
                          : '💳 ', // Emoji por defecto
                      style: const TextStyle(fontSize: 16),
                    ),
                    Text(
                      order.paymentMethods.isNotEmpty
                          ? order.paymentMethods[0]
                          : 'tm',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              // Cuarta fila: Calificación con estrellas
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFF252A3A), // Más claro
                  borderRadius: BorderRadius.circular(12),
                  // Sombra interna más pronunciada
                  boxShadow: [
                    // Sombra principal
                    BoxShadow(
                      color: Colors.black.withOpacity(0.7),
                      blurRadius: 6,
                      offset: const Offset(0, 3),
                      spreadRadius: -2,
                    ),
                    // Brillo sutil en la parte superior
                    BoxShadow(
                      color: Colors.white.withOpacity(0.08),
                      blurRadius: 1,
                      offset: const Offset(0, -1),
                      spreadRadius: 0,
                    ),
                  ],
                ),
                child: _buildRatingRow(order),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRatingRow(NostrEvent order) {
    // Calificación en un rango de 0 a 5
    final rating = order.rating?.totalRating ?? 0.0;
    final trades = order.rating?.totalReviews ?? 0;
    final daysOld = 50; // Valor por defecto

    return Row(
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
            // Estrellas con más brillo
            Row(
              children: List.generate(5, (index) {
                // Color ámbar más brillante para las estrellas
                const starColor = Color(0xFFFFD700);
                if (index < rating.floor()) {
                  // Estrella completa
                  return const Icon(Icons.star, color: starColor, size: 14);
                } else if (index == rating.floor() && rating % 1 > 0) {
                  // Estrella parcial
                  return const Icon(Icons.star_half,
                      color: starColor, size: 14);
                } else {
                  // Estrella vacía
                  return Icon(Icons.star_border,
                      color: starColor.withOpacity(0.3), size: 14);
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
    );
  }
}
