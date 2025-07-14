import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/deep_link_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';

class DeepLinkHandler {
  final Ref _ref;
  final Logger _logger = Logger();
  StreamSubscription<Uri>? _subscription;

  DeepLinkHandler(this._ref);

  /// Initializes deep link handling for the app
  void initialize(GoRouter router) {
    _logger.i('Initializing DeepLinkHandler');

    // Get the deep link service instance
    final deepLinkService = _ref.read(deepLinkServiceProvider);

    // Initialize the deep link service
    deepLinkService.initialize();

    // Listen for deep link events
    _subscription = deepLinkService.deepLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri, router),
      onError: (error) => _logger.e('Deep link stream error: $error'),
    );
  }

  /// Handles initial deep link from app launch
  Future<void> handleInitialDeepLink(Uri uri, GoRouter router) async {
    await _handleDeepLink(uri, router);
  }

  /// Handles incoming deep links
  Future<void> _handleDeepLink(
    Uri uri,
    GoRouter router,
  ) async {
    try {
      _logger.i('Handling deep link: $uri');

      // Check if it's a mostro: scheme
      if (uri.scheme == 'mostro') {
        await _handleMostroDeepLink(uri.toString(), router);
      } else {
        _logger.w('Unsupported deep link scheme: ${uri.scheme}');
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _showErrorSnackBar(context, S.of(context)!.unsupportedLinkFormat);
        }
      }
    } catch (e) {
      _logger.e('Error handling deep link: $e');
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, S.of(context)!.failedToOpenLink);
      }
    }
  }

  /// Handles mostro: scheme deep links
  Future<void> _handleMostroDeepLink(
    String url,
    GoRouter router,
  ) async {
    BuildContext? context;
    try {
      // Show loading indicator
      context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null) {
        _showLoadingDialog(context);
      }

      // Get the services
      final nostrService = _ref.read(nostrServiceProvider);
      final deepLinkService = _ref.read(deepLinkServiceProvider);

      // Process the mostro link
      final result = await deepLinkService.processMostroLink(url, nostrService, context!);

      // Get fresh context after async operation
      final currentContext = router.routerDelegate.navigatorKey.currentContext;
      
      // Hide loading indicator
      if (currentContext != null && currentContext.mounted) {
        Navigator.of(currentContext).pop();
      }

      if (result.isSuccess && result.orderInfo != null) {
        // Navigate to the appropriate screen with proper timing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          deepLinkService.navigateToOrder(router, result.orderInfo!);
        });
        _logger.i('Successfully navigated to order: ${result.orderInfo!.orderId} (${result.orderInfo!.orderType.value})');
      } else {
        final errorContext = router.routerDelegate.navigatorKey.currentContext;
        if (errorContext != null && errorContext.mounted) {
          final errorMessage = result.error ?? S.of(errorContext)!.failedToLoadOrder;
          _showErrorSnackBar(errorContext, errorMessage);
        }
        _logger.w('Failed to process mostro link: ${result.error}');
      }
    } catch (e) {
      _logger.e('Error processing mostro deep link: $e');
      final errorContext = router.routerDelegate.navigatorKey.currentContext;
      if (errorContext != null && errorContext.mounted) {
        Navigator.of(errorContext).pop(); // Hide loading if still showing
        _showErrorSnackBar(errorContext, S.of(errorContext)!.failedToOpenOrder);
      }
    }
  }

  /// Shows a loading dialog
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(S.of(dialogContext)!.loadingOrder),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows an error snack bar
  void _showErrorSnackBar(BuildContext? context, String message) {
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Disposes the deep link handler
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    // DeepLinkService disposal is handled by Riverpod provider
  }
}

/// Provider for the deep link handler service
final deepLinkHandlerProvider = Provider<DeepLinkHandler>((ref) {
  final handler = DeepLinkHandler(ref);
  ref.onDispose(() {
    handler.dispose();
  });
  return handler;
});

// NostrService provider is imported from shared/providers/nostr_service_provider.dart
