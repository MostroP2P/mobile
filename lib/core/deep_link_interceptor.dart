import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:mostro_mobile/services/logger_service.dart';

/// A deep link interceptor that prevents custom schemes from reaching GoRouter
/// This prevents assertion failures when the system tries to parse mostro: URLs
class DeepLinkInterceptor extends WidgetsBindingObserver {
  final StreamController<String> _customUrlController = 
      StreamController<String>.broadcast();

  /// Stream for custom URLs that were intercepted
  Stream<String> get customUrlStream => _customUrlController.stream;

  /// Initialize the interceptor
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    logger.i('DeepLinkInterceptor initialized');
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    logger.i('DeepLinkInterceptor: Route information received: $uri');

    // Check if this is a custom scheme URL
    if (_isCustomScheme(uri)) {
      logger.i('DeepLinkInterceptor: Custom scheme detected: ${uri.scheme}, intercepting and preventing GoRouter processing');

      // Emit the custom URL for processing
      _customUrlController.add(uri.toString());

      // Return true to indicate we handled this route, preventing it from
      // reaching GoRouter and causing assertion failures
      return true;
    }

    logger.i('DeepLinkInterceptor: Allowing normal URL to pass through: $uri');
    // Let normal URLs pass through to GoRouter
    return super.didPushRouteInformation(routeInformation);
  }

  // Note: didPushRoute is deprecated, but we keep it for compatibility
  // The main handling is done in didPushRouteInformation above
  @override
  // ignore: deprecated_member_use
  Future<bool> didPushRoute(String route) async {
    logger.i('DeepLinkInterceptor: didPushRoute called with: $route');

    try {
      final uri = Uri.parse(route);
      if (_isCustomScheme(uri)) {
        logger.i('DeepLinkInterceptor: Custom scheme detected in didPushRoute: ${uri.scheme}, intercepting');
        _customUrlController.add(route);
        return true;
      }
    } catch (e) {
      logger.w('DeepLinkInterceptor: Error parsing route in didPushRoute: $e');
    }

    // ignore: deprecated_member_use
    return super.didPushRoute(route);
  }

  /// Check if the URI uses a custom scheme
  bool _isCustomScheme(Uri uri) => isCustomSchemeUri(uri);

  /// Whether the URI uses a scheme the app resolves itself, such as `mostro:`
  static bool isCustomSchemeUri(Uri uri) =>
      uri.scheme.isNotEmpty && !uri.scheme.startsWith('http');

  /// [isCustomSchemeUri] for an unparsed location; unparseable means no
  static bool isCustomSchemeLocation(String location) {
    final uri = Uri.tryParse(location);
    return uri != null && isCustomSchemeUri(uri);
  }

  /// Dispose the interceptor
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customUrlController.close();
    logger.i('DeepLinkInterceptor disposed');
  }
}