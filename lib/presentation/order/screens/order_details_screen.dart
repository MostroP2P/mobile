import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/data/models/order_model.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_bloc.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_event.dart';
import 'package:mostro_mobile/presentation/order/bloc/order_details_state.dart';
import 'package:mostro_mobile/presentation/widgets/bottom_nav_bar.dart';

class OrderDetailsScreen extends StatelessWidget {
  final OrderModel initialOrder;

  const OrderDetailsScreen({super.key, required this.initialOrder});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          OrderDetailsBloc()..add(LoadOrderDetails(initialOrder)),
      child: BlocBuilder<OrderDetailsBloc, OrderDetailsState>(
        builder: (context, state) {
          if (state.status == OrderDetailsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == OrderDetailsStatus.error) {
            return Center(
                child: Text(state.errorMessage ?? 'An error occurred'));
          }
          if (state.order == null) {
            return const Center(child: Text('Order not found'));
          }
          return _buildContent(context, state.order!);
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, OrderModel order) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const HeroIcon(HeroIcons.arrowLeft, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title:
            const Text('ORDER DETAILS', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const HeroIcon(HeroIcons.plus, color: Colors.white),
            onPressed: () {
              // Implementar lógica para añadir
            },
          ),
          IconButton(
            icon: const HeroIcon(HeroIcons.bolt,
                style: HeroIconStyle.solid, color: Color(0xFF8CC541)),
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
                    _buildSellerInfo(order),
                    const SizedBox(height: 16),
                    _buildSellerAmount(order),
                    const SizedBox(height: 16),
                    _buildExchangeRate(order),
                    const SizedBox(height: 16),
                    _buildBuyerInfo(order),
                    const SizedBox(height: 16),
                    _buildBuyerAmount(order),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
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

  Widget _buildSellerInfo(OrderModel order) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.sellerName,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('${order.sellerRating}/5 (${order.sellerReviewCount})',
                    style: const TextStyle(color: Color(0xFF8CC541))),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // Implementar lógica para leer reseñas
            },
            child: const Text('Read reviews',
                style: TextStyle(color: Color(0xFF8CC541))),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerAmount(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${order.fiatAmount} ${order.fiatCurrency} (${order.premium})',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          Text('${order.satsAmount} sats',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              const HeroIcon(HeroIcons.creditCard,
                  style: HeroIconStyle.outline, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(order.paymentMethod,
                  style: const TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExchangeRate(OrderModel order) {
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
          Row(
            children: [
              const Text('price yado.io', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const HeroIcon(HeroIcons.arrowsUpDown,
                    style: HeroIconStyle.outline,
                    color: Colors.white,
                    size: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerInfo(OrderModel order) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.grey,
            child: Text('A', style: TextStyle(color: Colors.white)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Anon (you)',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
                Text('0/5 (0)', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          HeroIcon(HeroIcons.bolt,
              style: HeroIconStyle.solid, color: Color(0xFF8CC541)),
        ],
      ),
    );
  }

  Widget _buildBuyerAmount(OrderModel order) {
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
          const SizedBox(height: 8),
          const Row(
            children: [
              HeroIcon(HeroIcons.bolt,
                  style: HeroIconStyle.solid, color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Bitcoin Lightning Network',
                  style: TextStyle(color: Colors.white)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              context.read<OrderDetailsBloc>().add(CancelOrder());
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
              context.read<OrderDetailsBloc>().add(ContinueOrder());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8CC541),
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
