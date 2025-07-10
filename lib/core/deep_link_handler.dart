import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
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

    // Initialize the deep link service
    DeepLinkService.initialize();

    // Listen for deep link events
    _subscription = DeepLinkService.deepLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri, router),
      onError: (error) => _logger.e('Deep link stream error: $error'),
    );
  }

  /// Handles incoming deep links
  Future<void> _handleDeepLink(
    Uri uri,
    GoRouter router,
  ) async {
    try {
      _logger.i('Handling deep link: $uri');

      // Check if it's a nostr: scheme
      if (uri.scheme == 'nostr') {
        await _handleNostrDeepLink(uri.toString(), router);
      } else {
        _logger.w('Unsupported deep link scheme: ${uri.scheme}');
        _showErrorSnackBar(router.routerDelegate.navigatorKey.currentContext,
            'Unsupported link format');
      }
    } catch (e) {
      _logger.e('Error handling deep link: $e');
      _showErrorSnackBar(router.routerDelegate.navigatorKey.currentContext,
          'Failed to open link');
    }
  }

  /// Handles nostr: scheme deep links
  Future<void> _handleNostrDeepLink(
    String url,
    GoRouter router,
  ) async {
    try {
      // Show loading indicator
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null) {
        _showLoadingDialog(context);
      }

      // Get the NostrService
      final nostrService = _ref.read(nostrServiceProvider);

      // Process the nostr link
      final result = await DeepLinkService.processNostrLink(url, nostrService);

      // Hide loading indicator
      if (context != null && context.mounted) {
        Navigator.of(context).pop();
      }

      if (result.isSuccess && result.orderInfo != null) {
        // Navigate to the appropriate screen
        DeepLinkService.navigateToOrder(router, result.orderInfo!);
        _logger.i('Successfully navigated to order: ${result.orderInfo!.orderId} (${result.orderInfo!.orderType.value})');
      } else {
        if (context != null && context.mounted) {
          _showErrorSnackBar(context, result.error ?? 'Failed to load order');
        }
        _logger.w('Failed to process nostr link: ${result.error}');
      }
    } catch (e) {
      _logger.e('Error processing nostr deep link: $e');
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        Navigator.of(context).pop(); // Hide loading if still showing
        _showErrorSnackBar(context, 'Failed to open order');
      }
    }
  }

  /// Shows a loading dialog
  void _showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading order...'),
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
    DeepLinkService.dispose();
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
