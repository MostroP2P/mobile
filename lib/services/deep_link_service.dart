import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:dart_nostr/dart_nostr.dart';
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

  /// Processes a mostro: deep link and resolves order information
  Future<DeepLinkResult> processMostroLink(
    String url,
    NostrService nostrService,
  ) async {
    try {
      _logger.i('Processing mostro link: $url');

      // Validate URL format
      if (!NostrUtils.isValidMostroUrl(url)) {
        return DeepLinkResult.error('Invalid mostro: URL format');
      }

      // Parse the mostro URL
      final orderInfo = NostrUtils.parseMostroUrl(url);
      if (orderInfo == null) {
        return DeepLinkResult.error('Failed to parse mostro: URL');
      }

      final orderId = orderInfo['orderId'] as String;
      final relays = orderInfo['relays'] as List<String>;

      _logger.i('Parsed order ID: $orderId, relays: $relays');

      // Fetch the order info directly using the order ID
      final fetchedOrderInfo = await _fetchOrderInfoById(
        orderId,
        relays,
        nostrService,
      );

      if (fetchedOrderInfo == null) {
        return DeepLinkResult.error('Order not found or invalid');
      }

      return DeepLinkResult.success(fetchedOrderInfo);
    } catch (e) {
      _logger.e('Error processing mostro link: $e');
      return DeepLinkResult.error('Failed to process deep link: $e');
    }
  }

  /// Fetches order information using the order ID by searching for NIP-69 events with 'd' tag
  Future<OrderInfo?> _fetchOrderInfoById(
    String orderId,
    List<String> relays,
    NostrService nostrService,
  ) async {
    try {
      // Create a filter to search for NIP-69 order events with the specific order ID
      final filter = NostrFilter(
        kinds: [38383], // NIP-69 order events
        additionalFilters: {'#d': [orderId]}, // Order ID is stored in 'd' tag
      );

      List<NostrEvent> events = [];

      // First try to fetch from specified relays
      if (relays.isNotEmpty) {
        // Use the existing _fetchFromSpecificRelays method pattern
        final orderEvents = await nostrService.fecthEvents(filter);
        events.addAll(orderEvents);
      }

      // If no events found and we have default relays, try those
      if (events.isEmpty) {
        _logger.i('Order not found in specified relays, trying default relays');
        final defaultEvents = await nostrService.fecthEvents(filter);
        events.addAll(defaultEvents);
      }

      // Process the first matching event
      if (events.isNotEmpty) {
        final event = events.first;
        
        // Extract order type from 'k' tag
        final kTag = event.tags?.firstWhere(
          (tag) => tag.isNotEmpty && tag[0] == 'k',
          orElse: () => <String>[],
        );
        
        if (kTag != null && kTag.length > 1) {
          final orderTypeValue = kTag[1];
          final orderType = orderTypeValue == 'sell' 
              ? OrderType.sell 
              : OrderType.buy;
          
          return OrderInfo(
            orderId: orderId,
            orderType: orderType,
          );
        }
      }

      return null;
    } catch (e) {
      _logger.e('Error fetching order info by ID: $e');
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
