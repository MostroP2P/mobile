import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/app/app_theme.dart';
import 'package:mostro_mobile/presentation/auth/bloc/auth_state.dart';
import 'package:mostro_mobile/providers/riverpod_providers.dart';
import 'package:mostro_mobile/app/app_routes.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/biometrics_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'generated/l10n.dart';
import 'package:mostro_mobile/presentation/widgets/notification_listener_widget.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final nostrService = NostrService();
  await nostrService.init();

  final prefs = await SharedPreferences.getInstance();
  final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;

  final biometricsHelper = BiometricsHelper();

  runApp(
    ProviderScope(
      overrides: [
        isFirstLaunchProvider.overrideWithValue(isFirstLaunch),
        biometricsHelperProvider.overrideWithValue(biometricsHelper),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen to authentication state changes
    ref.listen<AuthState>(authNotifierProvider, (previous, state) {
      // Schedule navigation after the current frame is rendered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        if (state is AuthAuthenticated || state is AuthRegistrationSuccess) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.home);
        } else if (state is AuthUnregistered || state is AuthUnauthenticated) {
          Navigator.of(context).pushReplacementNamed(AppRoutes.welcome);
        }
      });
    });

    final isFirstLaunch = ref.watch(isFirstLaunchProvider);
    final navigatorKey = GlobalKey<NavigatorState>();

    return MaterialApp(
      title: 'Mostro',
      theme: AppTheme.theme,
      initialRoute: isFirstLaunch ? AppRoutes.welcome : AppRoutes.home,
      navigatorKey: navigatorKey,
      routes: AppRoutes.routes,
      onGenerateRoute: AppRoutes.onGenerateRoute,
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.delegate.supportedLocales,
      builder: (context, child) {
        return NotificationListenerWidget(navigator: navigatorKey, child: child!);
      },
    );
  }
}
