import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:mostro_mobile/features/disputes/screens/dispute_details_screen.dart';
import 'package:mostro_mobile/features/disputes/screens/disputes_list_screen.dart';

import 'package:mostro_mobile/features/walkthrough/providers/first_run_provider.dart';
import 'package:mostro_mobile/shared/widgets/navigation_listener_widget.dart';
import 'package:mostro_mobile/shared/widgets/notification_listener_widget.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/generated/l10n.dart';

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    navigatorKey: GlobalKey<NavigatorState>(),
    initialLocation: '/',
    redirect: (context, state) {
      // Redirect custom schemes to home to prevent assertion failures
      if (state.uri.scheme == 'mostro' || 
          (!state.uri.scheme.startsWith('http') && state.uri.scheme.isNotEmpty)) {
        return '/';
      }
      final firstRunState = ref.read(firstRunProvider);

      return firstRunState.when(
        data: (isFirstRun) {
          if (isFirstRun && state.matchedLocation != '/walkthrough') {
            return '/walkthrough';
          }
          return null;
        },
        loading: () {
          // While loading, prevent navigation to home by redirecting to walkthrough
          // The walkthrough route will handle the loading state appropriately
          return state.matchedLocation == '/walkthrough' ? null : '/walkthrough';
        },
        error: (_, __) => null,
      );
    },
    errorBuilder: (context, state) {
      final logger = Logger();
      logger.w('GoRouter error: ${state.error}');
      
      // For errors, show a generic error page
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64),
              const SizedBox(height: 16),
              Text(S.of(context)!.deepLinkNavigationError(state.error.toString())),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: Text(S.of(context)!.deepLinkGoHome),
              ),
            ],
          ),
        ),
      );
    },
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
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/welcome',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const WelcomeScreen(),
            ),
          ),
          GoRoute(
            path: '/order_book',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const TradesScreen(),
            ),
          ),
          GoRoute(
            path: '/trade_detail/:orderId',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: TradeDetailScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
          ),
          GoRoute(
            path: '/chat_list',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const ChatRoomsScreen(),
            ),
          ),
          GoRoute(
            path: '/disputes',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const DisputesListScreen(),
            ),
          ),
          GoRoute(
            path: '/chat_room/:orderId',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: ChatRoomScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
          ),
          GoRoute(
            path: '/dispute_details/:disputeId',
            pageBuilder: (context, state) {
              final disputeId = state.pathParameters['disputeId']!;
              return buildPageWithDefaultTransition<void>(
                context: context,
                state: state,
                child: DisputeDetailsScreen(disputeId: disputeId),
              );
            },
          ),
          GoRoute(
            path: '/register',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const RegisterScreen(),
            ),
          ),
          GoRoute(
            path: '/relays',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const RelaysScreen(),
            ),
          ),
          GoRoute(
            path: '/key_management',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const KeyManagementScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/about',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: const AboutScreen(),
            ),
          ),
          GoRoute(
            path: '/walkthrough',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: WalkthroughScreen(),
            ),
          ),
          GoRoute(
            path: '/add_order',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
              context: context,
              state: state,
              child: AddOrderScreen(),
            ),
          ),
          GoRoute(
            path: '/rate_user/:orderId',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: RateCounterpartScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
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
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: OrderConfirmationScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
          ),
          GoRoute(
            path: '/pay_invoice/:orderId',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: PayLightningInvoiceScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
          ),
          GoRoute(
            path: '/add_invoice/:orderId',
            pageBuilder: (context, state) =>
                buildPageWithDefaultTransition<void>(
                    context: context,
                    state: state,
                    child: AddLightningInvoiceScreen(
                      orderId: state.pathParameters['orderId']!,
                    )),
          ),
        ],
      ),
    ],
  );
}

CustomTransitionPage buildPageWithDefaultTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurveTween(curve: Curves.easeInOut).animate(animation),
        child: child,
      );
    },
    transitionDuration: const Duration(milliseconds: 150),
  );
}
