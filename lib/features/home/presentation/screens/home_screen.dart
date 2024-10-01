import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:heroicons/heroicons.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_state.dart';
import '../bloc/home_bloc.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/order_list.dart';
import '../widgets/bottom_nav_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D212C),
      appBar: const CustomAppBar(),
      body: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          if (state.status == HomeStatus.initial) {
            context.read<HomeBloc>().add(LoadOrders());
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == HomeStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state.status == HomeStatus.loaded) {
            return _buildContent(context, state);
          } else if (state.status == HomeStatus.error) {
            return const Center(child: Text('Error loading orders', style: TextStyle(color: Colors.white)));
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, HomeState state) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFF303544),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildTabs(context, state),
          _buildFilterButton(state),
          Expanded(
            child: state.filteredOrders.isEmpty
                ? const Center(child: Text('No orders available', style: TextStyle(color: Colors.white)))
                : OrderList(orders: state.filteredOrders),
          ),
          const BottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context, HomeState state) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1D212C),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab("BUY BTC", state.orderType == OrderType.buy, OrderType.buy, context),
          ),
          Expanded(
            child: _buildTab("SELL BTC", state.orderType == OrderType.sell, OrderType.sell, context),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, bool isActive, OrderType type, BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<HomeBloc>().add(ChangeOrderType(type));
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF303544) : const Color(0xFF1D212C),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isActive ? 20 : 0),
            topRight: Radius.circular(isActive ? 20 : 0),
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? const Color(0xFF8CC541) : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterButton(HomeState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: () {},
            icon: const HeroIcon(HeroIcons.funnel, style: HeroIconStyle.outline, color: Colors.white),
            label: const Text("FILTER", style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            "${state.filteredOrders.length} offers",
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
    );
  }
}