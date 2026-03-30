import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/deep_link_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class DeepLinkHandler {
  final Ref _ref;
  StreamSubscription<Uri>? _subscription;

  bool _isHandlingMostroDeepLink = false;
  String? _lastHandledDeepLinkUrl;
  DateTime? _lastHandledDeepLinkAt;

  BuildContext? _loadingDialogContext;
  bool _isLoadingDialogVisible = false;

  DeepLinkHandler(this._ref);

  /// Initializes deep link handling for the app
  void initialize(GoRouter router) {
    logger.i('Initializing DeepLinkHandler');

    // Get the deep link service instance
    final deepLinkService = _ref.read(deepLinkServiceProvider);

    // Initialize the deep link service
    deepLinkService.initialize();

    // Listen for deep link events
    _subscription = deepLinkService.deepLinkStream.listen(
      (Uri uri) => _handleDeepLink(uri, router),
      onError: (error) => logger.e('Deep link stream error: $error'),
    );
  }

  /// Handles initial deep link from app launch
  Future<void> handleInitialDeepLink(Uri uri, GoRouter router) async {
    await _handleDeepLink(uri, router);
  }

  /// Handles incoming deep links
  Future<void> _handleDeepLink(Uri uri, GoRouter router) async {
    try {
      logger.i('Handling deep link: $uri');

      // Check if it's a mostro: scheme
      if (uri.scheme == 'mostro') {
        await _handleMostroDeepLink(uri.toString(), router);
      } else {
        logger.w('Unsupported deep link scheme: ${uri.scheme}');
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          _showErrorSnackBar(context, S.of(context)!.unsupportedLinkFormat);
        }
      }
    } catch (e) {
      logger.e('Error handling deep link: $e');
      final context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showErrorSnackBar(context, S.of(context)!.failedToOpenLink);
      }
    }
  }

  /// Handles mostro: scheme deep links
  Future<void> _handleMostroDeepLink(String url, GoRouter router) async {
    final now = DateTime.now();
    final isDuplicateRecent =
        _lastHandledDeepLinkUrl == url &&
        _lastHandledDeepLinkAt != null &&
        now.difference(_lastHandledDeepLinkAt!) < const Duration(seconds: 2);

    if (_isHandlingMostroDeepLink || isDuplicateRecent) {
      logger.i('Ignoring duplicate/concurrent deep link handling for: $url');
      return;
    }

    _isHandlingMostroDeepLink = true;
    _lastHandledDeepLinkUrl = url;
    _lastHandledDeepLinkAt = now;

    BuildContext? context;
    try {
      // Show loading indicator
      context = router.routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showLoadingDialog(context);
      }

      // Get the services
      final nostrService = _ref.read(nostrServiceProvider);
      final deepLinkService = _ref.read(deepLinkServiceProvider);

      // Ensure we have a valid context for processing
      final processingContext =
          context ?? router.routerDelegate.navigatorKey.currentContext;
      if (processingContext == null || !processingContext.mounted) {
        logger.e('No valid context available for deep link processing');
        return;
      }

      // Process the mostro link
      final result = await deepLinkService.processMostroLink(
        url,
        nostrService,
        processingContext,
      );

      _hideLoadingDialog();

      if (result.isSuccess && result.orderInfo != null) {
        final orderInfo = result.orderInfo!;
        final currentContext =
            router.routerDelegate.navigatorKey.currentContext;

        // Check if the deep link targets a different Mostro instance
        if (orderInfo.mostroPubkey != null &&
            currentContext != null &&
            currentContext.mounted) {
          final currentPubkey = _ref.read(settingsProvider).mostroPublicKey;
          if (orderInfo.mostroPubkey != currentPubkey) {
            final shouldSwitch = await _showMostroSwitchDialog(
              currentContext,
              orderInfo.mostroPubkey!,
              currentPubkey,
            );
            if (shouldSwitch != true) {
              logger.i('User declined Mostro switch for deep link');
              return;
            }
            // Switch Mostro instance
            await _ref
                .read(settingsProvider.notifier)
                .updateMostroInstance(orderInfo.mostroPubkey!);
            logger.i('Switched Mostro instance to: ${orderInfo.mostroPubkey}');
          }
        }

        // Navigate to the appropriate screen with proper timing
        WidgetsBinding.instance.addPostFrameCallback((_) {
          deepLinkService.navigateToOrder(router, orderInfo);
        });
        logger.i(
          'Successfully navigated to order: ${orderInfo.orderId} (${orderInfo.orderType.value})',
        );
      } else {
        final errorContext = router.routerDelegate.navigatorKey.currentContext;
        if (errorContext != null && errorContext.mounted) {
          final errorMessage =
              result.error ?? S.of(errorContext)!.failedToLoadOrder;
          _showErrorSnackBar(errorContext, errorMessage);
        }
        logger.w('Failed to process mostro link: ${result.error}');
      }
    } catch (e) {
      logger.e('Error processing mostro deep link: $e');
      _hideLoadingDialog();

      final errorContext = router.routerDelegate.navigatorKey.currentContext;
      if (errorContext != null && errorContext.mounted) {
        _showErrorSnackBar(errorContext, S.of(errorContext)!.failedToOpenOrder);
      }
    } finally {
      _isHandlingMostroDeepLink = false;
    }
  }

  /// Shows a confirmation dialog when a deep link targets a different Mostro instance.
  ///
  /// [targetName] and [currentName] are optional human-readable labels for the
  /// Mostro instances. When empty, truncated pubkeys are shown instead.
  Future<bool?> _showMostroSwitchDialog(
    BuildContext context,
    String linkPubkey,
    String currentPubkey, {
    String targetName = '',
    String currentName = '',
  }) {
    final completer = Completer<bool?>();
    final s = S.of(context)!;
    final truncatedLink =
        '${linkPubkey.substring(0, 8)}...${linkPubkey.substring(linkPubkey.length - 8)}';
    final truncatedCurrent =
        '${currentPubkey.substring(0, 8)}...${currentPubkey.substring(currentPubkey.length - 8)}';

    final targetLabel = targetName.isNotEmpty ? targetName : truncatedLink;
    final currentLabel = currentName.isNotEmpty
        ? currentName
        : truncatedCurrent;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) {
        completer.complete(null);
        return;
      }
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Expanded(child: Text(s.deepLinkDifferentMostroTitle)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.deepLinkDifferentMostroBody),
              const SizedBox(height: 12),
              Text(
                '${s.deepLinkDifferentMostroFrom}\n$targetLabel',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                '${s.deepLinkDifferentMostroCurrent}\n$currentLabel',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(s.cancel),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(s.deepLinkSwitchAndView),
            ),
          ],
        ),
      );
      completer.complete(result);
    });

    return completer.future;
  }

  /// Shows a loading dialog
  void _showLoadingDialog(BuildContext context) {
    if (_isLoadingDialogVisible) {
      return;
    }

    _isLoadingDialogVisible = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _loadingDialogContext = dialogContext;
        return Center(
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
        );
      },
    ).whenComplete(() {
      _isLoadingDialogVisible = false;
      _loadingDialogContext = null;
    });
  }

  void _hideLoadingDialog() {
    if (!_isLoadingDialogVisible) {
      return;
    }

    final dialogContext = _loadingDialogContext;
    if (dialogContext != null && dialogContext.mounted) {
      Navigator.of(dialogContext).pop();
    }

    _isLoadingDialogVisible = false;
    _loadingDialogContext = null;
  }

  /// Shows an error snack bar
  void _showErrorSnackBar(BuildContext? context, String message) {
    if (context == null) return;

    SnackBarHelper.showTopSnackBar(
      context,
      message,
      duration: const Duration(seconds: 3),
      backgroundColor: Colors.red,
    );
  }

  /// Disposes the deep link handler
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _hideLoadingDialog();
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
