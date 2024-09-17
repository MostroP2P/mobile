import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import 'home_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late HomeBloc _homeBloc;

  @override
  void initState() {
    super.initState();
    _homeBloc = HomeBloc();
    _homeBloc.add(LoadOrders());
  }

  @override
  void dispose() {
    _homeBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => _homeBloc,
      child: BlocBuilder<HomeBloc, HomeState>(
        builder: (context, state) {
          return HomeView(
            isBuySelected: state.isBuySelected,
            orders: state.orders,
            isLoading: state.isLoading,
            onBuyPressed: () => _homeBloc.add(const ToggleBuySell(true)),
            onSellPressed: () => _homeBloc.add(const ToggleBuySell(false)),
            onOrderSelected: (order) => _homeBloc.add(SelectOrder(order)),
          );
        },
      ),
    );
  }
}
