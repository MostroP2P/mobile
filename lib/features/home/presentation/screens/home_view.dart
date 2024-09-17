import 'package:flutter/material.dart';
import '../../../../core/widgets/custom_bottom_nav_bar.dart';
import '../../../../core/widgets/custom_tab_bar.dart';
import '../widgets/order_list.dart';
import '../../../../data/models/order_model.dart';

class HomeView extends StatelessWidget {
  final bool isBuySelected;
  final List<OrderModel> orders;
  final bool isLoading;
  final VoidCallback onBuyPressed;
  final VoidCallback onSellPressed;
  final Function(OrderModel) onOrderSelected;

  const HomeView({
    super.key,
    required this.isBuySelected,
    required this.orders,
    required this.isLoading,
    required this.onBuyPressed,
    required this.onSellPressed,
    required this.onOrderSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mostro P2P'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // todo: Implementar lógica para crear nueva orden
            },
          ),
          IconButton(
            icon: const Icon(Icons.bolt),
            onPressed: () {
              // todo: Implementar lógica del botón de acción rápida
            },
          ),
        ],
      ),
      body: Column(
        children: [
          CustomTabBar(
            onBuyPressed: onBuyPressed,
            onSellPressed: onSellPressed,
            isBuySelected: isBuySelected,
          ),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : OrderList(
                    orders: orders,
                    onOrderSelected: onOrderSelected,
                  ),
          ),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: 0,
        onTap: (index) {
          // todo: Implementar lógica de navegación
        },
      ),
    );
  }
}
