import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:app_links/app_links.dart';
import 'package:mostro_mobile/core/app_routes.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/deep_link_handler.dart';
import 'package:mostro_mobile/core/deep_link_interceptor.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/services/lifecycle_manager.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/locale_notifier.dart';
import 'package:mostro_mobile/features/walkthrough/providers/first_run_provider.dart';
import 'package:mostro_mobile/features/restore/restore_overlay.dart';

class MostroApp extends ConsumerStatefulWidget {
  const MostroApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  ConsumerState<MostroApp> createState() => _MostroAppState();
}

class _MostroAppState extends ConsumerState<MostroApp> {
  GoRouter? _router;
  bool _deepLinksInitialized = false;
  bool _notificationLaunchHandled = false;
  DeepLinkInterceptor? _deepLinkInterceptor;
  StreamSubscription<String>? _customUrlSubscription;

  @override
  void initState() {
    super.initState();
    ref.read(lifecycleManagerProvider);
    _initializeDeepLinkInterceptor();
    _processInitialDeepLink();
  }

  /// Initialize the deep link interceptor
  void _initializeDeepLinkInterceptor() {
    _deepLinkInterceptor = DeepLinkInterceptor();
    _deepLinkInterceptor!.initialize();
    
    // Listen for intercepted custom URLs
    _customUrlSubscription = _deepLinkInterceptor!.customUrlStream.listen(
      (url) async {
        debugPrint('Intercepted custom URL: $url');
        
        // Process the URL through our deep link handler
        if (_router != null) {
          try {
            final uri = Uri.parse(url);
            final deepLinkHandler = ref.read(deepLinkHandlerProvider);
            await deepLinkHandler.handleInitialDeepLink(uri, _router!);
          } catch (e) {
            debugPrint('Error handling intercepted URL: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('Error in custom URL stream: $error');
      },
    );
  }

  /// Process initial deep link before router initialization
  Future<void> _processInitialDeepLink() async {
    try {
      final appLinks = AppLinks();
      final initialUri = await appLinks.getInitialLink();
      
      if (initialUri != null && initialUri.scheme == 'mostro') {
        // Store the initial mostro URL for later processing
        // and prevent it from being passed to GoRouter
        debugPrint('Initial mostro deep link detected: $initialUri');
        
        // Schedule the deep link processing after the router is ready
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleInitialMostroLink(initialUri);
        });
      }
    } catch (e) {
      debugPrint('Error processing initial deep link: $e');
    }
  }

  /// Handle initial mostro link after router is ready
  Future<void> _handleInitialMostroLink(Uri uri) async {
    try {
      // Wait for router to be ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (_router != null) {
        final deepLinkHandler = ref.read(deepLinkHandlerProvider);
        await deepLinkHandler.handleInitialDeepLink(uri, _router!);
      }
    } catch (e) {
      debugPrint('Error handling initial mostro link: $e');
    }
  }

  @override
  void dispose() {
    _customUrlSubscription?.cancel();
    _deepLinkInterceptor?.dispose();
    // Deep link handler disposal is handled automatically by Riverpod
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final initAsyncValue = ref.watch(appInitializerProvider);

    return initAsyncValue.when(
      data: (_) {
        // Initialize first run provider
        ref.watch(firstRunProvider);

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

        // Watch both system locale and settings for changes
        final systemLocale = ref.watch(systemLocaleProvider);
        final settings = ref.watch(settingsProvider);

        // Initialize router if not already done
        _router ??= createRouter(ref);

        // Initialize deep links after router is created
        if (!_deepLinksInitialized && _router != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              final deepLinkHandler = ref.read(deepLinkHandlerProvider);
              deepLinkHandler.initialize(_router!);

              _deepLinksInitialized = true;
            } catch (e, stackTrace) {
              // Log the error but don't set _deepLinksInitialized to true
              // This allows retries on subsequent builds
              debugPrint('Failed to initialize deep links: $e');
              debugPrint('Stack trace: $stackTrace');
            }
          });
        }

        // Check if app was launched from a notification tap (terminated state)
        if (!_notificationLaunchHandled && _router != null) {
          _notificationLaunchHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final orderId = await getNotificationLaunchOrderId();
            if (!mounted) return;
            if (orderId != null && orderId.isNotEmpty) {
              debugPrint('App launched from notification tap, navigating to order: $orderId');
              _router!.push('/trade_detail/$orderId');
            }
          });
        }

        return MaterialApp.router(
          title: 'Mostro',
          theme: AppTheme.theme,
          darkTheme: AppTheme.theme,
          routerConfig: _router!,
          builder: (context, child) {
            return Stack(
              children: [
                if (child != null) child,
                const RestoreOverlay(),
              ],
            );
          },
          // Use language override from settings if available, otherwise let callback handle detection
          locale: settings.selectedLanguage != null
              ? Locale(settings.selectedLanguage!)
              : systemLocale,
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          localeResolutionCallback: (locale, supportedLocales) {
            // Use the current system locale from our provider
            final deviceLocale = locale ?? systemLocale;

            // Check for Spanish language code (es) - includes es_AR, es_ES, etc.
            if (deviceLocale.languageCode == 'es') {
              return const Locale('es');
            }

            // Check for exact match with any supported locale
            for (var supportedLocale in supportedLocales) {
              if (supportedLocale.languageCode == deviceLocale.languageCode) {
                return supportedLocale;
              }
            }

            // If no match found, return Spanish as fallback
            return const Locale('es');
          },
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
