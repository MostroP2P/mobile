import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Firebase Cloud Messaging service for push notifications
class FCMService {
  final Logger _logger = Logger();
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> Function()? _onMessageReceivedCallback;

  static const String _fcmTokenKey = 'fcm_token';
  static const String _fcmTopic = 'mostro_notifications';

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  Future<void> initialize({
    Future<void> Function()? onMessageReceived,
  }) async {
    if (_isInitialized) {
      _logger.i('FCM service already initialized');
      return;
    }

    try {
      _logger.i('=== FCM INITIALIZATION START ===');

      _onMessageReceivedCallback = onMessageReceived;
      _logger.i('Callback configured: ${onMessageReceived != null}');

      _logger.i('Requesting notification permissions...');
      final permissionGranted = await _requestPermissions();
      _logger.i('Permission granted: $permissionGranted');
      if (!permissionGranted) {
        _logger.w('Notification permissions not granted');
        return;
      }

      _logger.i('Getting FCM token...');
      await _getAndStoreToken();

      _logger.i('Subscribing to FCM topic...');
      await _subscribeToTopic();

      _logger.i('Setting up token refresh listener...');
      _setupTokenRefreshListener();

      _logger.i('Setting up foreground message handler...');
      _setupForegroundMessageHandler();

      _isInitialized = true;
      _logger.i('=== FCM INITIALIZATION COMPLETE ===');
    } catch (e, stackTrace) {
      _logger.e('Failed to initialize FCM service: $e');
      _logger.e('Stack trace: $stackTrace');
      _logger.w('App will continue without FCM push notifications');
      rethrow;
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      _logger.i('Requesting notification permissions');

      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final granted = settings.authorizationStatus == AuthorizationStatus.authorized;
      _logger.i('Permission status: ${settings.authorizationStatus}');

      return granted;
    } catch (e) {
      _logger.e('Error requesting permissions: $e');
      return false;
    }
  }

  Future<void> _getAndStoreToken() async {
    try {
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.w('Timeout getting FCM token');
          return null;
        },
      );

      if (token != null) {
        _logger.i('FCM token obtained: ${token.substring(0, 20)}...');
        await _saveToken(token);
      } else {
        _logger.w('FCM token is null - push notifications may not work');
      }
    } catch (e) {
      _logger.e('Error getting FCM token: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_fcmTokenKey, token);
      _logger.i('FCM token saved');
    } catch (e) {
      _logger.e('Error saving FCM token: $e');
    }
  }

  Future<void> _subscribeToTopic() async {
    try {
      await _messaging.subscribeToTopic(_fcmTopic).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.w('Timeout subscribing to topic: $_fcmTopic');
        },
      );
      _logger.i('Subscribed to topic: $_fcmTopic');
    } catch (e) {
      _logger.e('Error subscribing to topic: $e');
    }
  }

  void _setupTokenRefreshListener() {
    _messaging.onTokenRefresh.listen(
      (newToken) {
        _logger.i('FCM token refreshed: ${newToken.substring(0, 20)}...');
        _saveToken(newToken);
      },
      onError: (error) {
        _logger.e('Error in token refresh listener: $error');
      },
    );
  }

  void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        _logger.i('Received foreground FCM message');

        if (_onMessageReceivedCallback != null) {
          try {
            await _onMessageReceivedCallback!();
            _logger.i('Event processing completed');
          } catch (e) {
            _logger.e('Error processing events: $e');
          }
        } else {
          _logger.w('No callback configured');
        }
      },
      onError: (error) {
        _logger.e('Error in message handler: $error');
      },
    );
  }

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_fcmTokenKey);
    } catch (e) {
      _logger.e('Error getting stored FCM token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          _logger.w('Timeout deleting FCM token');
        },
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_fcmTokenKey);
      _logger.i('FCM token deleted');
    } catch (e) {
      _logger.e('Error deleting FCM token: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_fcmTokenKey);
        _logger.i('FCM token removed from local storage');
      } catch (localError) {
        _logger.e('Error removing token from local storage: $localError');
      }
    }
  }

  void dispose() {
    _isInitialized = false;
  }
}

final fcmServiceProvider = Provider<FCMService>((ref) {
  final service = FCMService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
