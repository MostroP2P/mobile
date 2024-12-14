import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/features/add_order/screens/add_order_screen.dart';
import 'package:mostro_mobile/features/auth/screens/welcome_screen.dart';
import 'package:mostro_mobile/features/home/screens/home_screen.dart';
import 'package:mostro_mobile/presentation/chat_list/screens/chat_list_screen.dart';
import 'package:mostro_mobile/presentation/profile/screens/profile_screen.dart';
import 'package:mostro_mobile/features/auth/screens/register_screen.dart';

final goRouter = GoRouter(
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
  ],
  initialLocation: '/welcome', // or '/' depending on your logic
);
