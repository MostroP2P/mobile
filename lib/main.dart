import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mostro_mobile/presentation/welcome/screens/welcome_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/data/repositories/auth_repository.dart';
import 'package:mostro_mobile/data/repositories/order_repository.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_bloc.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_event.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_state.dart';
import 'package:mostro_mobile/presentation/auth/screens/login_screen.dart';
import 'package:mostro_mobile/presentation/auth/screens/register_screen.dart';
import 'package:mostro_mobile/presentation/home/bloc/home_bloc.dart';
import 'package:mostro_mobile/presentation/home/screens/home_screen.dart';
import 'package:mostro_mobile/services/nostr_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nostrService = NostrService();
  await nostrService.init();

  final authRepository = AuthRepository();
  final orderRepository = OrderRepository(nostrService);

  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  runApp(MyApp(
    nostrService: nostrService,
    authRepository: authRepository,
    orderRepository: orderRepository,
    isFirstLaunch: isFirstLaunch,
  ));
}

class MyApp extends StatelessWidget {
  final NostrService nostrService;
  final AuthRepository authRepository;
  final OrderRepository orderRepository;
  final bool isFirstLaunch;

  const MyApp({
    super.key,
    required this.nostrService,
    required this.authRepository,
    required this.orderRepository,
    required this.isFirstLaunch,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(
          create: (context) => AuthBloc(authRepository: authRepository),
        ),
        BlocProvider<HomeBloc>(
          create: (context) => HomeBloc(orderRepository),
        ),
      ],
      child: MaterialApp(
        title: 'Mostro',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF1D212C),
        ),
        home: isFirstLaunch ? const WelcomeScreen() : const SplashScreen(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/register': (context) => const RegisterScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AuthBloc>().add(AuthCheckRequested());
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          Navigator.of(context).pushReplacementNamed('/home');
        } else if (state is AuthUnauthenticated) {
          Navigator.of(context).pushReplacementNamed('/login');
        } else if (state is AuthUnregistered) {
          Navigator.of(context).pushReplacementNamed('/register');
        }
      },
      child: const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}