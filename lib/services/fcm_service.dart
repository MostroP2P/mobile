import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing Firebase Cloud Messaging (FCM) functionality
///
/// This service handles:
/// - FCM token generation and storage
/// - Token refresh handling
/// - Notification permissions
/// - Foreground message handling
class FCMService {
  final Logger _logger = Logger();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmTopic = 'mostro_notifications';

  bool _isInitialized = false;

  /// Initializes the FCM service
  ///
  /// This should be called early in the app lifecycle, typically during app initialization
  Future<void> initialize() async {
    if (_isInitialized) {
      _logger.i('FCM service already initialized');
      return;
    }

    try {
      _logger.i('Initializing FCM service...');

      // Request notification permissions
      final permissionGranted = await _requestPermissions();
      if (!permissionGranted) {
        _logger.w('Notification permissions not granted');
        return;
      }

      // Get and store initial FCM token
      await _getAndStoreToken();

      // Subscribe to topic for silent push notifications
      await _subscribeToTopic();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Set up foreground message handler
      _setupForegroundMessageHandler();

      _isInitialized = true;
      _logger.i('FCM service initialized successfully');
    } catch (e) {
      _logger.e('Failed to initialize FCM service: $e');
      rethrow;
    }
  }

  /// Requests notification permissions from the user
  Future<bool> _requestPermissions() async {
    try {
      _logger.i('Requesting notification permissions...');

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;

      _logger.i('Notification permission status: ${settings.authorizationStatus}');

      return granted;
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      return false;
    }
  }

  /// Gets the FCM token and stores it in SharedPreferences
  Future<void> _getAndStoreToken() async {
    try {
      final token = await _messaging.getToken();

      if (token != null) {
        _logger.i('FCM token obtained: ${token.substring(0, 20)}...');
        await _saveToken(token);
      } else {
        _logger.w('FCM token is null');
      }
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
    }
  }

  /// Saves the FCM token to SharedPreferences
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      _logger.i('FCM token saved to SharedPreferences');
    } catch (e) {
      _logger.e('Error saving FCM token: $e');
    }
  }

  /// Subscribes to the FCM topic for broadcast notifications
  Future<void> _subscribeToTopic() async {
    try {
      await _messaging.subscribeToTopic(_fcmTopic);
      _logger.i('Subscribed to FCM topic: $_fcmTopic');
    } catch (e) {
      _logger.e('Error subscribing to FCM topic: $e');
    }
  }

  /// Sets up a listener for FCM token refresh
  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen(
      (newToken) {
        _logger.i('FCM token refreshed: ${newToken.substring(0, 20)}...');
        _saveToken(newToken);
        // TODO: Send new token to backend when available
      },
      onError: (error) {
        _logger.e('Error in token refresh listener: $error');
      },
    );
  }

  /// Sets up handler for foreground messages
  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) {
        _logger.i('Received foreground FCM message');
        _logger.d('Message data: ${message.data}');

        // TODO: Process foreground messages
        // For now, just log them
        if (message.notification != null) {
          _logger.i('Notification title: ${message.notification!.title}');
          _logger.i('Notification body: ${message.notification!.body}');
        }
      },
      onError: (error) {
        _logger.e('Error in foreground message handler: $error');
      },
    );
  }

  /// Gets the currently stored FCM token
  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fcmTokenKey);
    } catch (e) {
      _logger.e('Error getting stored FCM token: $e');
      return null;
    }
  }

  /// Deletes the stored FCM token
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      _logger.i('FCM token deleted');
    } catch (e) {
      _logger.e('Error deleting FCM token: $e');
    }
  }

  /// Cleans up resources
  void dispose() {
    _isInitialized = false;
  }
}

/// Provider for the FCM service
final fcmServiceProvider = Provider<FCMService>((ref) {
  final service = FCMService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
