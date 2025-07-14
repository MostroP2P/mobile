import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:logger/logger.dart';

/// A deep link interceptor that prevents custom schemes from reaching GoRouter
/// This prevents assertion failures when the system tries to parse mostro: URLs
class DeepLinkInterceptor extends WidgetsBindingObserver {
  final Logger _logger = Logger();
  final StreamController<String> _customUrlController = 
      StreamController<String>.broadcast();

  /// Stream for custom URLs that were intercepted
  Stream<String> get customUrlStream => _customUrlController.stream;

  /// Initialize the interceptor
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _logger.i('DeepLinkInterceptor initialized');
  }

  @override
  Future<bool> didPushRouteInformation(RouteInformation routeInformation) async {
    final uri = routeInformation.uri;
    _logger.i('Route information received: $uri');

    // Check if this is a custom scheme URL
    if (_isCustomScheme(uri)) {
      _logger.i('Custom scheme detected: ${uri.scheme}, intercepting');
      
      // Emit the custom URL for processing
      _customUrlController.add(uri.toString());
      
      // Return true to indicate we handled this route, preventing it from
      // reaching GoRouter and causing assertion failures
      return true;
    }

    // Let normal URLs pass through to GoRouter
    return super.didPushRouteInformation(routeInformation);
  }

  // Note: didPushRoute is deprecated, but we keep it for compatibility
  // The main handling is done in didPushRouteInformation above

  /// Check if the URI uses a custom scheme
  bool _isCustomScheme(Uri uri) {
    return uri.scheme == 'mostro' || 
           (!uri.scheme.startsWith('http') && uri.scheme.isNotEmpty);
  }

  /// Dispose the interceptor
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _customUrlController.close();
    _logger.i('DeepLinkInterceptor disposed');
  }
}