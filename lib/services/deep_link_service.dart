import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/services/nostr_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Contains order information extracted from a Nostr event
class OrderInfo {
  final String orderId;
  final OrderType orderType;

  const OrderInfo({
    required this.orderId,
    required this.orderType,
  });
}

class DeepLinkService {
  final Logger _logger = Logger();
  final AppLinks _appLinks = AppLinks();

  // Stream controller for deep link events
  final StreamController<Uri> _deepLinkController = StreamController<Uri>.broadcast();
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
          _logger.i('Deep link received while app running: $uri');
          _handleDeepLink(uri);
        },
        onError: (Object err) {
          _logger.e('Deep link stream error: $err');
        },
      );

      // Check for deep link when app is launched
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _logger.i('App launched with deep link: $initialUri');
        _handleDeepLink(initialUri);
      }

      _isInitialized = true;
      _logger.i('DeepLinkService initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize DeepLinkService: $e');
      rethrow;
    }
  }

  /// Handles incoming deep links
  void _handleDeepLink(Uri uri) {
    _deepLinkController.add(uri);
  }

  /// Processes a nostr: deep link and resolves order information
  Future<DeepLinkResult> processNostrLink(
    String url,
    NostrService nostrService,
  ) async {
    try {
      _logger.i('Processing nostr link: $url');

      // Validate URL format
      if (!NostrUtils.isValidNostrUrl(url)) {
        return DeepLinkResult.error('Invalid nostr: URL format');
      }

      // Parse the nevent
      final eventInfo = NostrUtils.parseNostrUrl(url);
      if (eventInfo == null) {
        return DeepLinkResult.error('Failed to parse nostr: URL');
      }

      final eventId = eventInfo['eventId'] as String;
      final relays = eventInfo['relays'] as List<String>;

      _logger.i('Parsed event ID: $eventId, relays: $relays');

      // Fetch the order info from the event's tags
      final orderInfo = await _fetchOrderInfoFromEvent(
        eventId,
        relays,
        nostrService,
      );

      if (orderInfo == null) {
        return DeepLinkResult.error('Order not found or invalid');
      }

      return DeepLinkResult.success(orderInfo);
    } catch (e) {
      _logger.e('Error processing nostr link: $e');
      return DeepLinkResult.error('Failed to process deep link: $e');
    }
  }

  /// Fetches order information from the specified event's tags
  Future<OrderInfo?> _fetchOrderInfoFromEvent(
    String eventId,
    List<String> relays,
    NostrService nostrService,
  ) async {
    try {
      // First try to fetch from specified relays
      if (relays.isNotEmpty) {
        final orderInfo = await nostrService.fetchOrderInfoByEventId(eventId, relays);
        if (orderInfo != null) {
          return orderInfo;
        }
      }

      // Fallback: try fetching from default relays
      _logger.i('Event not found in specified relays, trying default relays');
      return await nostrService.fetchOrderInfoByEventId(eventId);
    } catch (e) {
      _logger.e('Error fetching order info from event: $e');
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
    _logger.i('Navigating to: $route (Order: ${orderInfo.orderId}, Type: ${orderInfo.orderType.value})');
    router.push(route);
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

  const DeepLinkResult._({
    required this.isSuccess,
    this.orderInfo,
    this.error,
  });

  factory DeepLinkResult.success(OrderInfo orderInfo) {
    return DeepLinkResult._(
      isSuccess: true,
      orderInfo: orderInfo,
    );
  }

  factory DeepLinkResult.error(String error) {
    return DeepLinkResult._(
      isSuccess: false,
      error: error,
    );
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
