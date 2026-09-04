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
import 'package:mostro_mobile/core/deep_link_schemes.dart';
import 'package:mostro_mobile/features/auth/providers/auth_notifier_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/auth/notifiers/auth_state.dart';
import 'package:mostro_mobile/services/lifecycle_manager.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/features/notifications/services/background_notification_service.dart';
import 'package:mostro_mobile/shared/providers/app_init_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/shared/notifiers/locale_notifier.dart';
import 'package:mostro_mobile/features/community/providers/community_selector_provider.dart';
import 'package:mostro_mobile/features/walkthrough/providers/first_run_provider.dart';
import 'package:mostro_mobile/features/restore/restore_overlay.dart';
import 'package:mostro_mobile/shared/widgets/nwc_notification_listener.dart';
import 'package:mostro_mobile/shared/widgets/test_environment_banner.dart';

class MostroApp extends ConsumerStatefulWidget {
  const MostroApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  ConsumerState<MostroApp> createState() => _MostroAppState();
}

/// How many frames a pending deep link waits before it is dropped
const _maxDeepLinkAttempts = 10;

class _MostroAppState extends ConsumerState<MostroApp> {
  GoRouter? _router;
  bool _deepLinksInitialized = false;
  bool _notificationLaunchHandled = false;
  DeepLinkInterceptor? _deepLinkInterceptor;
  Uri? _pendingDeepLink;
  int _deepLinkAttempts = 0;
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
      (url) {
        logger.i('Intercepted custom URL: $url');
        final uri = Uri.tryParse(url);
        if (uri == null) {
          logger.w('Ignoring unparseable custom URL: $url');
          return;
        }
        _queueDeepLink(uri);
      },
      onError: (error) {
        logger.e('Error in custom URL stream: $error');
      },
    );
  }

  /// Process initial deep link before router initialization
  Future<void> _processInitialDeepLink() async {
    Uri? initialUri;
    try {
      initialUri = await AppLinks().getInitialLink();
    } catch (e, stack) {
      logger.e('Error processing initial deep link',
          error: e, stackTrace: stack);
    }
    initialUri ??= _platformDefaultDeepLink();

    if (initialUri != null && isCustomSchemeUri(initialUri)) {
      logger.i('Initial deep link detected: $initialUri');
      _queueDeepLink(initialUri);
    }
  }

  /// The cold start link createRouter discards, in case app_links missed it
  Uri? _platformDefaultDeepLink() {
    final location =
        WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    if (!isCustomSchemeLocation(location)) return null;
    logger.i('Falling back to the platform default location: $location');
    return Uri.tryParse(location);
  }

  /// Keep the link until there is a router and a navigator to open it with.
  /// One slot is enough: links arrive one at a time, and the newest is the one
  /// the user just asked for.
  void _queueDeepLink(Uri uri) {
    if (_pendingDeepLink != null && _pendingDeepLink != uri) {
      logger.w('Replacing pending deep link $_pendingDeepLink with $uri');
    }
    _pendingDeepLink = uri;
    _deepLinkAttempts = 0;
    _deliverPendingDeepLink();
  }

  void _deliverPendingDeepLink() {
    if (!mounted) return;
    final uri = _pendingDeepLink;
    final router = _router;
    if (uri == null || router == null) return;

    // The handler needs the navigator, which only exists once the router has
    // rendered a frame.
    if (router.routerDelegate.navigatorKey.currentContext == null) {
      _retryPendingDeepLink();
      return;
    }

    _pendingDeepLink = null;
    unawaited(_handleDeepLink(uri, router));
  }

  /// Try again on the next frame, up to [_maxDeepLinkAttempts]. Retrying on
  /// consecutive frames keeps a link from opening an order long after the user
  /// asked for it.
  void _retryPendingDeepLink() {
    _deepLinkAttempts++;
    if (_deepLinkAttempts > _maxDeepLinkAttempts) {
      logger.w('Giving up on deep link $_pendingDeepLink');
      _pendingDeepLink = null;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _deliverPendingDeepLink();
    });
    // A post frame callback does not request a frame on its own.
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  Future<void> _handleDeepLink(Uri uri, GoRouter router) async {
    var handled = false;
    try {
      handled = await ref
          .read(deepLinkHandlerProvider)
          .handleInitialDeepLink(uri, router);
    } catch (e, stack) {
      logger.e('Error handling deep link', error: e, stackTrace: stack);
    }
    if (handled) {
      _deepLinkAttempts = 0;
      return;
    }
    // The app was not in a state to open it, so keep it for another frame.
    if (!mounted) return;
    _pendingDeepLink ??= uri;
    _retryPendingDeepLink();
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
        // Watch providers that affect routing
        ref.watch(firstRunProvider);
        // Refresh router when community selection state resolves
        ref.listen(communitySelectedProvider, (_, __) {
          _router?.refresh();
        });

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

        // Watch both system locale and the language override. Only the
        // language matters here; watching the whole Settings object rebuilt
        // MaterialApp.router on every relay sync write.
        final systemLocale = ref.watch(systemLocaleProvider);
        final selectedLanguage =
            ref.watch(settingsProvider.select((s) => s.selectedLanguage));

        // Initialize router if not already done
        _router ??= createRouter(ref);
        _deliverPendingDeepLink();

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
              logger.e('Failed to initialize deep links',
                  error: e, stackTrace: stackTrace);
            }
          });
        }

        // Check if app was launched from a notification tap (terminated state)
        if (!_notificationLaunchHandled && _router != null) {
          _notificationLaunchHandled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final payload = await getNotificationLaunchOrderId();
            if (!mounted) return;
            if (payload != null && payload.isNotEmpty) {
              final route = resolveNotificationRoute(payload);
              logger.i(
                  'App launched from notification tap, navigating to: $route');
              _router!.push(route);
            }
          });
        }

        return MaterialApp.router(
          title: 'Mostro',
          theme: AppTheme.theme,
          darkTheme: AppTheme.theme,
          routerConfig: _router!,
          builder: (context, child) {
            return NwcNotificationListener(
              child: TestEnvironmentBanner(
                child: Stack(
                  children: [
                    if (child != null) child,
                    const RestoreOverlay(),
                  ],
                ),
              ),
            );
          },
          // Use language override from settings if available, otherwise let callback handle detection
          locale: selectedLanguage != null
              ? Locale(selectedLanguage)
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
