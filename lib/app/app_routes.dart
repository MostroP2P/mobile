import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/add_order/screens/add_order_screen.dart';
import 'package:mostro_mobile/features/add_order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/auth/screens/welcome_screen.dart';
import 'package:mostro_mobile/features/chat/screens/chat_list_screen.dart';
import 'package:mostro_mobile/features/home/screens/home_screen.dart';
import 'package:mostro_mobile/features/order_book/screens/order_book_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/take_order_screen.dart';
import 'package:mostro_mobile/features/auth/screens/register_screen.dart';
import 'package:mostro_mobile/shared/widgets/navigation_listener_widget.dart';
import 'package:mostro_mobile/shared/widgets/notification_listener_widget.dart';

final goRouter = GoRouter(
  navigatorKey: GlobalKey<NavigatorState>(),
  routes: [
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return NotificationListenerWidget(
          child: NavigationListenerWidget(
            child: child,
          ),
        );
      },
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/order_book',
          builder: (context, state) => const OrderBookScreen(),
        ),
        GoRoute(
          path: '/chat_list',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/add_order',
          builder: (context, state) => AddOrderScreen(),
        ),
        GoRoute(
          path: '/take_sell/:orderId',
          builder: (context, state) => TakeOrderScreen(
            orderId: state.pathParameters['orderId']!,
            orderType: OrderType.sell,
          ),
        ),
        GoRoute(
          path: '/take_buy/:orderId',
          builder: (context, state) => TakeOrderScreen(
            orderId: state.pathParameters['orderId']!,
            orderType: OrderType.buy,
          ),
        ),
        GoRoute(
          path: '/order_confirmed/:orderId',
          builder: (context, state) => OrderConfirmationScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
        GoRoute(
          path: '/pay_invoice/:orderId',
          builder: (context, state) => PayLightningInvoiceScreen(
              orderId: state.pathParameters['orderId']!),
        ),
        GoRoute(
          path: '/add_invoice/:orderId',
          builder: (context, state) => AddLightningInvoiceScreen(
              orderId: state.pathParameters['orderId']!),
        ),
      ],
    ),
  ],
  initialLocation: '/',
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text(state.error.toString())),
  ),
);
