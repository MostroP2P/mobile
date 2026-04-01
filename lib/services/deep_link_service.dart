import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Contains order information extracted from a Nostr event
class OrderInfo {
  final String orderId;
  final OrderType orderType;

  /// Mostro instance pubkey from the deep link, if present.
  final String? mostroPubkey;

  const OrderInfo({
    required this.orderId,
    required this.orderType,
    this.mostroPubkey,
  });
}

class DeepLinkService {
  final AppLinks _appLinks = AppLinks();

  // Stream controller for deep link events
  final StreamController<Uri> _deepLinkController =
      StreamController<Uri>.broadcast();
  Stream<Uri> get deepLinkStream => _deepLinkController.stream;

  // Flag to track if service is initialized
  bool _isInitialized = false;

  /// Initializes the deep link service and sets up listeners
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Listen for incoming deep links when app is already running
      _appLinks.uriLinkStream.listen(
        (Uri uri) {
          logger.i('Deep link received while app running: $uri');
          _handleDeepLink(uri);
        },
        onError: (Object err) {
          logger.e('Deep link stream error: $err');
        },
      );

      // NOTE: We don't process the initial link here to avoid GoRouter conflicts
      // The initial link will be handled by the app initialization in app.dart

      _isInitialized = true;
      logger.i('DeepLinkService initialized successfully');
    } catch (e) {
      logger.e('Failed to initialize DeepLinkService: $e');
      rethrow;
    }
  }

  /// Handles incoming deep links
  void _handleDeepLink(Uri uri) {
    _deepLinkController.add(uri);
  }

  /// Processes a mostro: deep link and resolves order information
  Future<DeepLinkResult> processMostroLink(
    String url,
    NostrService nostrService,
    BuildContext context,
  ) async {
    try {
      logger.i('Processing mostro link: $url');

      // Validate URL format
      if (!NostrUtils.isValidMostroUrl(url)) {
        return DeepLinkResult.error(S.of(context)!.deepLinkInvalidFormat);
      }

      // Parse the mostro URL
      final orderInfo = NostrUtils.parseMostroUrl(url);
      if (orderInfo == null) {
        return DeepLinkResult.error(S.of(context)!.deepLinkParseError);
      }

      final orderId = orderInfo['orderId'] as String;
      final relays = orderInfo['relays'] as List<String>;
      final mostroPubkey = orderInfo['mostroPubkey'] as String?;

      // Validate order ID format (UUID-like string)
      if (orderId.isEmpty || orderId.length < 10) {
        return DeepLinkResult.error(S.of(context)!.deepLinkInvalidOrderId);
      }

      // Validate relays
      if (relays.isEmpty) {
        return DeepLinkResult.error(S.of(context)!.deepLinkNoRelays);
      }

      logger.i('Parsed order ID: $orderId, relays: $relays');

      // Fetch the order info directly using the order ID
      final fetchedOrderInfo = await _fetchOrderInfoById(
        orderId,
        relays,
        nostrService,
        mostroPubkey: mostroPubkey,
      );

      if (fetchedOrderInfo == null) {
        if (context.mounted) {
          return DeepLinkResult.error(S.of(context)!.deepLinkOrderNotFound);
        } else {
          return DeepLinkResult.error('Order not found or invalid');
        }
      }

      return DeepLinkResult.success(fetchedOrderInfo);
    } catch (e) {
      logger.e('Error processing mostro link: $e');
      return DeepLinkResult.error('Failed to process deep link: $e');
    }
  }

  /// Fetches order information using the order ID by searching for NIP-69 events with 'd' tag
  Future<OrderInfo?> _fetchOrderInfoById(
    String orderId,
    List<String> relays,
    NostrService nostrService, {
    String? mostroPubkey,
  }) async {
    try {
      // Create a filter to search for NIP-69 order events with the specific order ID
      final filter = NostrFilter(
        kinds: [38383], // NIP-69 order events
        additionalFilters: {
          '#d': [orderId],
        }, // Order ID is stored in 'd' tag
      );

      List<NostrEvent> events = [];

      // First try to fetch from specified relays
      if (relays.isNotEmpty) {
        final orderEvents = await nostrService.fetchEvents(
          filter,
          specificRelays: relays,
        );
        events.addAll(orderEvents);
      }

      // Helper to build the candidate list from a set of raw events.
      // When mostroPubkey is present only events authored by that node are
      // accepted. isVerified() failures are logged but not treated as hard
      // rejections due to a known dart_nostr limitation (consistent with
      // how mostro_nodes_notifier.dart handles kind-0 events).
      List<NostrEvent> buildCandidates(List<NostrEvent> raw) {
        if (mostroPubkey == null) return raw;
        return raw.where((e) {
          if (!e.isVerified()) {
            logger.w(
              'Event \${e.id} from pubkey \${e.pubkey} failed signature '
              'verification — rejecting to prevent spoofing.',
            );
            return false;
          }
          return e.pubkey == mostroPubkey;
        }).toList();
      }

      var candidateEvents = buildCandidates(events);

      // If no matching candidate was found in the link relays, retry with the
      // app's default relays. This covers the case where events from other
      // Mostro nodes were returned by the link relays (events non-empty but
      // candidateEvents empty), which previously skipped the fallback entirely.
      if (candidateEvents.isEmpty) {
        logger.i(
          'No matching event in specified relays, trying default relays',
        );
        final defaultEvents = await nostrService.fetchEvents(filter);
        events.addAll(defaultEvents);
        candidateEvents = buildCandidates(events);
      }

      if (candidateEvents.isEmpty && mostroPubkey != null) {
        logger.w(
          'Order $orderId not found for Mostro pubkey $mostroPubkey '
          '(found ${events.length} event(s) from other nodes)',
        );
        return null;
      }

      // Process the first matching event
      if (candidateEvents.isNotEmpty) {
        final event = candidateEvents.first;

        // Extract order type from 'k' tag
        final kTag = event.tags?.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'k',
          orElse: () => <String>[],
        );

        if (kTag != null && kTag.length > 1) {
          final orderTypeValue = kTag[1];
          final OrderType? orderType;
          if (orderTypeValue == 'sell') {
            orderType = OrderType.sell;
          } else if (orderTypeValue == 'buy') {
            orderType = OrderType.buy;
          } else {
            logger.w('Unknown order type in k tag: $orderTypeValue');
            return null;
          }

          return OrderInfo(
            orderId: orderId,
            orderType: orderType,
            mostroPubkey: mostroPubkey,
          );
        }
      }

      return null;
    } catch (e) {
      logger.e('Error fetching order info by ID: $e');
      return null;
    }
  }

  /// Determines the appropriate navigation route for an order
  String getNavigationRoute(OrderInfo orderInfo) {
    // Navigate to the correct take order screen based on order type
    switch (orderInfo.orderType) {
      case OrderType.sell:
        return '/take_sell/${orderInfo.orderId}';
      case OrderType.buy:
        return '/take_buy/${orderInfo.orderId}';
    }
  }

  /// Navigates to the appropriate screen for the given order
  void navigateToOrder(GoRouter router, OrderInfo orderInfo) {
    final route = getNavigationRoute(orderInfo);
    logger.i(
      'Navigating to: $route (Order: ${orderInfo.orderId}, Type: ${orderInfo.orderType.value})',
    );

    // Use post-frame callback to ensure navigation happens after the current frame
    // This prevents GoRouter assertion failures during app lifecycle transitions
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Validate that the router is still in a valid state before navigation
        final context = router.routerDelegate.navigatorKey.currentContext;
        if (context != null && context.mounted) {
          router.push(route);
        } else {
          logger.w('Router context is not available for navigation to: $route');
        }
      } catch (e) {
        logger.e('Error navigating to order: $e');
        // Fallback: try using go instead of push if push fails
        try {
          router.go(route);
        } catch (fallbackError) {
          logger.e('Fallback navigation also failed: $fallbackError');
        }
      }
    });
  }

  /// Cleans up resources
  void dispose() {
    _deepLinkController.close();
    _isInitialized = false;
  }
}

/// Result of processing a deep link
class DeepLinkResult {
  final bool isSuccess;
  final OrderInfo? orderInfo;
  final String? error;

  const DeepLinkResult._({required this.isSuccess, this.orderInfo, this.error});

  factory DeepLinkResult.success(OrderInfo orderInfo) {
    return DeepLinkResult._(isSuccess: true, orderInfo: orderInfo);
  }

  factory DeepLinkResult.error(String error) {
    return DeepLinkResult._(isSuccess: false, error: error);
  }
}

/// Provider for the deep link service
final deepLinkServiceProvider = Provider<DeepLinkService>((ref) {
  final service = DeepLinkService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
