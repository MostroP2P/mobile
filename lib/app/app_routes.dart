import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/features/add_order/screens/add_order_screen.dart';
import 'package:mostro_mobile/features/add_order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/auth/screens/welcome_screen.dart';
import 'package:mostro_mobile/features/home/screens/home_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/take_buy_order_screen.dart';
import 'package:mostro_mobile/features/take_order/screens/take_sell_order_screen.dart';
import 'package:mostro_mobile/presentation/chat_list/screens/chat_list_screen.dart';
import 'package:mostro_mobile/presentation/profile/screens/profile_screen.dart';
import 'package:mostro_mobile/features/auth/screens/register_screen.dart';
import 'package:mostro_mobile/shared/widgets/navigation_listener_widget.dart';
import 'package:mostro_mobile/shared/widgets/notification_listener_widget.dart';

final goRouter = GoRouter(
  navigatorKey: GlobalKey<NavigatorState>(),
  routes: [
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        // Wrap the Navigator with your listener widgets
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
          path: '/chat_list',
          builder: (context, state) => const ChatListScreen(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
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
          builder: (context, state) =>
              TakeSellOrderScreen(orderId: state.pathParameters['orderId']!),
        ),
        GoRoute(
          path: '/take_buy/:orderId',
          builder: (context, state) =>
              TakeBuyOrderScreen(orderId: state.pathParameters['orderId']!),
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
  initialLocation: '/welcome',
  errorBuilder: (context, state) => Scaffold(
    body: Center(child: Text(state.error.toString())),
  ),
);
