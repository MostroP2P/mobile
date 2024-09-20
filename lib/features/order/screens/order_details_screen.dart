import 'package:flutter/material.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/features/home/data/models/order_model.dart';
import 'package:mostro_mobile/features/home/presentation/widgets/bottom_nav_bar.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel order; // Asume que tienes un modelo de orden

  const OrderDetailsScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D212C),
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('ORDER DETAILS'),
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.plus),
            onPressed: () {
              // Implementar lógica para añadir
            },
          ),
          IconButton(
            icon: const HeroIcon(HeroIcons.bolt, style: HeroIconStyle.solid),
            onPressed: () {
              // Implementar lógica para acción de rayo
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    _buildSellerInfo(),
                    const SizedBox(height: 16),
                    _buildSellerAmount(),
                    const SizedBox(height: 16),
                    _buildExchangeRate(),
                    const SizedBox(height: 16),
                    _buildBuyerInfo(),
                    const SizedBox(height: 16),
                    _buildBuyerAmount(),
                    const SizedBox(height: 24),
                    _buildActionButtons(),
                  ],
                ),
              ),
            ),
          ),
          const BottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildSellerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(order.sellerAvatar),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(order.sellerName,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text('${order.sellerRating}/5 (${order.sellerReviewCount})',
                  style: const TextStyle(color: Colors.green)),
            ],
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              // Implementar lógica para leer reseñas
            },
            child: const Text('Read reviews',
                style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAmount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order.fiatAmount} ${order.fiatCurrency} (+${order.premium}%)',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('${order.satsAmount} sats',
              style: const TextStyle(color: Colors.grey)),
          Row(
            children: [
              const HeroIcon(HeroIcons.creditCard,
                  style: HeroIconStyle.outline, color: Colors.white),
              const SizedBox(width: 8),
              Text(order.paymentMethod,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRate() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('1 BTC = \$ ${order.exchangeRate}',
              style: const TextStyle(color: Colors.white)),
          const Row(
            children: [
              Text('price yado.io', style: TextStyle(color: Colors.grey)),
              HeroIcon(HeroIcons.arrowsUpDown,
                  style: HeroIconStyle.outline, color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            child: Text('A'),
          ),
          SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Anon (you)',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              Text('0/5 (0)', style: TextStyle(color: Colors.grey)),
            ],
          ),
          Spacer(),
          HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildBuyerAmount() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order.buyerSatsAmount} sats',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('\$ ${order.buyerFiatAmount}',
              style: const TextStyle(color: Colors.grey)),
          const Row(
            children: [
              HeroIcon(HeroIcons.bolt,
                  style: HeroIconStyle.outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Bitcoin Lightning Network',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Implementar lógica para cancelar
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('CANCEL'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Implementar lógica para continuar
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('CONTINUE'),
          ),
        ),
      ],
    );
  }
}
