import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/home/providers/home_order_providers.dart';
import 'package:mostro_mobile/features/home/widgets/order_list_item.dart';
import 'package:mostro_mobile/shared/widgets/add_order_button.dart'; // Importamos el botón
import 'package:mostro_mobile/shared/widgets/bottom_nav_bar.dart';
import 'package:mostro_mobile/shared/widgets/order_filter.dart';
import 'package:mostro_mobile/shared/widgets/mostro_app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the filtered orders directly.
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF171A23), // Color oscuro más específico
      appBar: _buildAppBar(),
      drawer: const MostroAppDrawer(),
      body: Stack(
        // Usamos Stack para superponer el botón
        children: [
          RefreshIndicator(
            onRefresh: () async {
              return await ref.refresh(filteredOrdersProvider);
            },
            child: Column(
              children: [
                _buildTabs(ref),
                _buildFilterButton(context, ref),
                Expanded(
                  child: Container(
                    color: const Color(0xFF171A23), // Fondo oscuro
                    child: filteredOrders.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.search_off,
                                  color: Colors.white30,
                                  size: 48,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No orders available',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Try changing filter settings or check back later',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredOrders.length,
                            padding: const EdgeInsets.only(
                                bottom: 80,
                                top: 6), // Padding para la navigation bar
                            itemBuilder: (context, index) {
                              final order = filteredOrders[index];
                              return OrderListItem(order: order);
                            },
                          ),
                  ),
                ),
                const BottomNavBar(),
              ],
            ),
          ),
          // Añadimos nuestro botón
          const AddOrderButton(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor:
          const Color(0xFF171A23), // Color más específico para el fondo
      elevation: 0,
      leadingWidth: 60,
      toolbarHeight: 56, // Altura exacta
      leading: Padding(
        padding: const EdgeInsets.only(left: 16.0),
        child: Builder(
          builder: (context) => IconButton(
            icon: const HeroIcon(
              HeroIcons.bars3,
              style: HeroIconStyle.outline,
              color: Colors.white,
              size: 24,
            ),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      actions: [
        // Notificación con indicador de número
        Padding(
          padding: const EdgeInsets.only(right: 16.0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const HeroIcon(
                  HeroIcons.bell,
                  style: HeroIconStyle.outline,
                  color: Colors.white,
                  size: 24,
                ),
                onPressed: () {
                  // Acción para notificaciones
                },
              ),
              // Indicador del número de notificaciones
              Positioned(
                top: 12,
                right: 8,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text(
                      '6',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs(WidgetRef ref) {
    final orderType = ref.watch(homeOrderTypeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF171A23), // Fondo oscuro exacto
        border: Border(
          bottom: BorderSide(
            color:
                Color(0xFF1E2230), // Color ligeramente más claro para el borde
            width: 1.0,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton(
            ref,
            "BUY BTC",
            orderType == OrderType.sell,
            OrderType.sell,
            const Color(0xFF8CC63F), // Verde exacto
          ),
          _buildTabButton(
            ref,
            "SELL BTC",
            orderType == OrderType.buy,
            OrderType.buy,
            const Color(0xFFEA384C), // Rojo exacto
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    WidgetRef ref,
    String text,
    bool isActive,
    OrderType type,
    Color activeColor,
  ) {
    return Expanded(
      child: InkWell(
        onTap: () => ref.read(homeOrderTypeProvider.notifier).state = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeColor : Colors.transparent,
                width: 3.0, // Línea más gruesa
              ),
            ),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isActive
                  ? activeColor
                  : const Color(
                      0xFF8A8D98), // Gris específico cuando no está activo
              fontWeight: FontWeight.w600, // Semi-bold
              fontSize: 15,
              letterSpacing: 0.5, // Espaciado entre letras
              fontFamily: 'Roboto', // Asumiendo Roboto como fuente
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(BuildContext context, WidgetRef ref) {
    final filteredOrders = ref.watch(filteredOrdersProvider);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: const Color(0xFF1A1F2C), // Color específico del fondo
      child: Align(
        alignment: Alignment.centerLeft, // Alineación a la izquierda
        child: GestureDetector(
          onTap: () {
            showModalBottomSheet(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (BuildContext context) {
                return const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: OrderFilter(),
                );
              },
            );
          },
          child: Container(
            margin: const EdgeInsets.only(
                left: 8), // Margen izquierdo para posicionarlo correctamente
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF252A3A), // Color específico del botón
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const HeroIcon(
                  HeroIcons.funnel,
                  style: HeroIconStyle.outline,
                  color: Colors.white70,
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Text(
                  "FILTER",
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  height: 16,
                  width: 1,
                  color: Colors.white.withOpacity(0.2),
                ),
                Text(
                  "${filteredOrders.length} offers",
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
