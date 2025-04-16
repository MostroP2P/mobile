import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/core/app_routes.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/shared/providers/background_service_provider.dart';

class MostroApp extends ConsumerStatefulWidget {
  const MostroApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  ConsumerState<MostroApp> createState() => _MostroAppState();
}

class _MostroAppState extends ConsumerState<MostroApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final isForeground = state == AppLifecycleState.resumed;
    final backgroundService = ref.read(backgroundServiceProvider);
    backgroundService.setForegroundStatus(isForeground);

  }

  @override
  Widget build(BuildContext context) {
    final initAsyncValue = ref.watch(appInitializerProvider);

    return initAsyncValue.when(
      data: (_) {
        ref.listen<AuthState>(authNotifierProvider, (previous, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            if (state is AuthAuthenticated ||
                state is AuthRegistrationSuccess) {
              context.go('/');
            } else if (state is AuthUnregistered ||
                state is AuthUnauthenticated) {
              context.go('/');
            }
          });
        });

        return MaterialApp.router(
          title: 'Mostro',
          theme: AppTheme.theme,
          darkTheme: AppTheme.theme,
          routerConfig: goRouter,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
        );
      },
      loading: () => MaterialApp(
        theme: AppTheme.theme,
        darkTheme: AppTheme.theme,
        home: Scaffold(
          backgroundColor: AppTheme.dark1,
          body: const Center(child: CircularProgressIndicator()),
        ),
      ),
      error: (err, stack) => MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Initialization Error: $err')),
        ),
      ),
    );
  }
}
