import 'package:flutter/material.dart';
import 'package:mostro_mobile/presentation/welcome/screens/welcome_screen.dart';
import 'package:mostro_mobile/presentation/home/screens/home_screen.dart';
import 'package:mostro_mobile/presentation/chat_list/screens/chat_list_screen.dart';
import 'package:mostro_mobile/presentation/profile/screens/profile_screen.dart';

class AppRoutes {
  static const String welcome = '/welcome';
  static const String home = '/';
  static const String chatList = '/chat_list';
  static const String profile = '/profile';

  static Map<String, WidgetBuilder> get routes => {
        welcome: (context) => const WelcomeScreen(),
        home: (context) => const HomeScreen(),
        chatList: (context) => const ChatListScreen(),
        profile: (context) => const ProfileScreen(),
      };

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (context) {
        switch (settings.name) {
          case welcome:
            return const WelcomeScreen();
          case home:
            return const HomeScreen();
          case chatList:
            return const ChatListScreen();
          case profile:
            return const ProfileScreen();
          default:
            return const Scaffold(
              body: Center(
                child: Text('No route defined'),
              ),
            );
        }
      },
    );
  }
}
