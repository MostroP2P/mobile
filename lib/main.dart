import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mostro_mobile/core/theme/app_theme.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'package:mostro_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:mostro_mobile/features/auth/screens/login_screen.dart';
import 'package:mostro_mobile/features/auth/screens/register_screen.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_event.dart';
import 'package:mostro_mobile/features/home/presentation/screens/home_screen.dart';
import 'package:mostro_mobile/features/home/presentation/bloc/home_bloc.dart';
import 'package:mostro_mobile/data/repositories/order_repository.dart';
import 'package:mostro_mobile/features/welcome/screens/welcome_screen.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
// ... otras importaciones

void main() async {
  await Hive.initFlutter();

  final nostrService = NostrService();
  await nostrService.init();
  runApp(MyApp(nostrService: nostrService));
}

class MyApp extends StatelessWidget {
  final dynamic nostrService;

  const MyApp({super.key, required this.nostrService});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(
            authRepository: AuthRepository(),
            nostrService: nostrService,
          ),
        ),
        BlocProvider<HomeBloc>(
          create: (context) => HomeBloc(
            orderRepository: OrderRepository(),
          )..add(LoadOrders()),
        ),
      ],
      child: MaterialApp(
        title: 'Mostro',
        theme: AppTheme.theme,
        initialRoute: '/',
        routes: {
          '/': (context) => FutureBuilder<bool>(
                future: AuthRepository().isRegistered(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  } else {
                    if (snapshot.data == true) {
                      return const LoginScreen();
                    } else {
                      return const WelcomeScreen();
                    }
                  }
                },
              ),
          '/welcome': (context) => const WelcomeScreen(),
          '/register': (context) => const RegisterScreen(),
          '/login': (context) => const LoginScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
