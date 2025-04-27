import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/features/chat/screens/chat_room_screen.dart';
import 'package:mostro_mobile/features/order/screens/add_order_screen.dart';
import 'package:mostro_mobile/features/order/screens/order_confirmation_screen.dart';
import 'package:mostro_mobile/features/auth/screens/welcome_screen.dart';
import 'package:mostro_mobile/features/chat/screens/chat_rooms_list.dart';
import 'package:mostro_mobile/features/home/screens/home_screen.dart';
import 'package:mostro_mobile/features/key_manager/key_management_screen.dart';
import 'package:mostro_mobile/features/rate/rate_counterpart_screen.dart';
import 'package:mostro_mobile/features/settings/about_screen.dart';
import 'package:mostro_mobile/features/settings/settings_screen.dart';
import 'package:mostro_mobile/features/trades/screens/trade_detail_screen.dart';
import 'package:mostro_mobile/features/trades/screens/trades_screen.dart';
import 'package:mostro_mobile/features/relays/relays_screen.dart';
import 'package:mostro_mobile/features/order/screens/add_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/order/screens/pay_lightning_invoice_screen.dart';
import 'package:mostro_mobile/features/order/screens/take_order_screen.dart';
import 'package:mostro_mobile/features/auth/screens/register_screen.dart';
import 'package:mostro_mobile/features/walkthrough/screens/walkthrough_screen.dart';
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
          path: '/',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const WelcomeScreen(),
        ),
        GoRoute(
          path: '/order_book',
          builder: (context, state) => const TradesScreen(),
        ),
        GoRoute(
          path: '/trade_detail/:orderId',
          builder: (context, state) => TradeDetailScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
        GoRoute(
          path: '/chat_list',
          builder: (context, state) => const ChatRoomsScreen(),
        ),
        GoRoute(
          path: '/chat_room/:orderId',
          builder: (context, state) => ChatRoomScreen(
            orderId: state.pathParameters['orderId']!,
          ),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/relays',
          builder: (context, state) => const RelaysScreen(),
        ),
        GoRoute(
          path: '/key_management',
          builder: (context, state) => const KeyManagementScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
        GoRoute(
          path: '/about',
          builder: (context, state) => const AboutScreen(),
        ),
        GoRoute(
          path: '/walkthrough',
          builder: (context, state) => WalkthroughScreen(),
        ),
        GoRoute(
          path: '/add_order',
          builder: (context, state) => AddOrderScreen(),
        ),
        GoRoute(
          path: '/rate_user/:orderId',
          builder: (context, state) => RateCounterpartScreen(
            orderId: state.pathParameters['orderId']!,
          ),
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
