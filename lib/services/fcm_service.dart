import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/services/logger_service.dart'
    show backgroundLog, logger;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mostro_mobile/firebase_options.dart';


/// FCM background message handler - wakes up the app to process new events.
/// This is called when the app is in background or terminated.
///
/// The handler follows MIP-05 approach:
/// - FCM sends silent/empty notifications (no content)
/// - This handler wakes up the app
/// - The existing background service handles fetching and processing events
///
/// NOTE: This handler runs in a separate Dart isolate where the project's
/// logger singleton is unavailable. All logging goes through backgroundLog()
/// (see logger_service.dart) instead of the main logger.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    // Skip on unsupported platforms
    if (kIsWeb || Platform.isLinux) return;

    // Initialize Firebase for background context (if not already initialized)
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final sharedPrefs = SharedPreferencesAsync();

    // Record wake timestamp for debugging and potential retry logic
    final now = (DateTime.now().millisecondsSinceEpoch / 1000).floor();
    await sharedPrefs.setInt('fcm.last_wake_timestamp', now);

    // Try to communicate with the background service
    // The existing flutter_background_service handles:
    // - Fetching new messages from Nostr relays
    // - Decrypting messages locally
    // - Displaying local notifications
    // - Updating badge count
    try {
      final service = FlutterBackgroundService();
      final isRunning = await service.isRunning();

      if (isRunning) {
        // Service is already running — signal it that FCM detected new activity
        service.invoke('fcm-wake', {});
      } else {
        // Service is dead — start it and send settings.
        // We set up listeners BEFORE startService() so we never miss events
        // that the background isolate emits during its synchronous setup.

        // 1. Listen for handlers-registered (emitted by serviceMain right
        //    after it registers its event handlers, before opening the DB).
        final handlersReady = Completer<void>();
        final handlersSub = service.on('handlers-registered').listen((_) {
          if (!handlersReady.isCompleted) handlersReady.complete();
        });

        // 2. Listen for service-ready (emitted after NostrService.init()).
        final serviceReady = Completer<void>();
        final readySub = service.on('service-ready').listen((_) {
          if (!serviceReady.isCompleted) serviceReady.complete();
        });

        final started = await service.startService();
        if (!started) {
          backgroundLog('startService() returned false, aborting');
          await handlersSub.cancel();
          await readySub.cancel();
          return;
        }

        final settingsJson = await sharedPrefs.getString(
          SharedPreferencesKeys.appSettings.value,
        );
        if (settingsJson == null) {
          backgroundLog('No settings found, service started without relay config');
          await handlersSub.cancel();
          await readySub.cancel();
          return;
        }

        Map<String, dynamic>? settings;
        try {
          settings = jsonDecode(settingsJson) as Map<String, dynamic>?;
        } catch (e) {
          backgroundLog('Failed to decode settings: $e');
        }

        if (settings == null) {
          await handlersSub.cancel();
          await readySub.cancel();
          return;
        }

        // 3. Wait for handlers to be registered (guarantees on('start') is
        //    active so our invoke won't be dropped).
        try {
          await handlersReady.future.timeout(const Duration(seconds: 5));
        } catch (_) {
          backgroundLog('Timeout waiting for handlers-registered, proceeding anyway');
        }
        await handlersSub.cancel();

        // 4. Send start and wait for ack (service-ready). Retry once on timeout.
        service.invoke('start', {'settings': settings});

        try {
          await serviceReady.future.timeout(const Duration(seconds: 5));
        } catch (_) {
          backgroundLog('No service-ready ack, retrying start');
          service.invoke('start', {'settings': settings});
          try {
            await serviceReady.future.timeout(const Duration(seconds: 3));
          } catch (_) {
            backgroundLog('Service did not acknowledge start after retry');
          }
        }
        await readySub.cancel();
      }
    } catch (e) {
      backgroundLog('background service error: $e');
    }
  } catch (e) {
    backgroundLog('background handler error: $e');
  }
}

class FCMService {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final SharedPreferencesAsync _prefs;

  static const String _fcmTokenKey = 'fcm_token';
  static const Duration _tokenTimeout = Duration(seconds: 10);

  StreamSubscription<String>? _tokenRefreshSubscription;
  StreamSubscription<RemoteMessage>? _foregroundMessageSubscription;

  bool _isInitialized = false;

  /// Callback invoked when FCM token is refreshed.
  /// Set this to re-register tokens with the push notification server.
  void Function(String newToken)? onTokenRefresh;

  FCMService(this._prefs);

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Skip Firebase initialization on web and Linux (not supported)
      if (kIsWeb || Platform.isLinux) {
        debugPrint('FCM: Skipping initialization on web/Linux (not supported)');
        return;
      }

      debugPrint('FCM: Starting initialization...');

      // Initialize Firebase (if not already initialized)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        debugPrint('FCM: Firebase initialized');
      } else {
        debugPrint('FCM: Firebase already initialized');
      }

      // Request notification permissions
      final permissionGranted = await _requestPermissions();
      if (permissionGranted) {
        debugPrint('FCM: Notification permissions granted');
      } else {
        debugPrint('FCM: Notification permissions not granted');
      }

      // Get and store FCM token
      await _getAndStoreToken();

      // Set up token refresh listener
      _setupTokenRefreshListener();

      // Set up foreground message listener
      _setupForegroundMessageListener();

      // Register background message handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      _isInitialized = true;
      debugPrint('FCM: Initialized successfully');
    } catch (e, stackTrace) {
      logger.e('Error initializing FCM Service: $e');
      logger.e('Stack trace: $stackTrace');
      // Don't rethrow - app should continue without FCM
    }
  }

  Future<bool> _requestPermissions() async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;

      logger
          .i('Notification permission status: ${settings.authorizationStatus}');
      return granted;
    } catch (e) {
      logger.e('Error requesting permissions: $e');
      return false;
    }
  }

  Future<String?> _getAndStoreToken() async {
    try {
      final token = await _messaging.getToken().timeout(
        _tokenTimeout,
        onTimeout: () {
          logger.w('Timeout getting FCM token');
          return null;
        },
      );

      if (token != null) {
        await _prefs.setString(_fcmTokenKey, token);
        debugPrint('FCM: Token obtained');
        return token;
      } else {
        logger
            .w('Failed to obtain FCM token - push notifications may not work');
        return null;
      }
    } catch (e) {
      logger.e('Error getting FCM token: $e');
      return null;
    }
  }

  void _setupTokenRefreshListener() {
    _tokenRefreshSubscription?.cancel();

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen(
      (newToken) async {
        debugPrint('FCM: Token refreshed');
        await _prefs.setString(_fcmTokenKey, newToken);

        // Notify listener (e.g., PushNotificationService) to re-register token
        try {
          onTokenRefresh?.call(newToken);
        } catch (e) {
          logger.e('Error in onTokenRefresh callback: $e');
        }
      },
      onError: (error) {
        logger.e('Error on token refresh: $error');
      },
    );
  }

  void _setupForegroundMessageListener() {
    _foregroundMessageSubscription?.cancel();

    _foregroundMessageSubscription = FirebaseMessaging.onMessage.listen(
      (RemoteMessage message) async {
        // Silent notification received while app is in foreground.
        // The existing background service subscription mechanism will
        // pick up new events automatically - no action needed here.
        debugPrint('FCM: Foreground message received');
      },
      onError: (error) {
        logger.e('Error receiving foreground message: $error');
      },
    );
  }

  Future<String?> getToken() async {
    try {
      // Try to get from storage first
      final storedToken = await _prefs.getString(_fcmTokenKey);
      if (storedToken != null) {
        return storedToken;
      }

      // If not in storage, get from Firebase
      return await _getAndStoreToken();
    } catch (e) {
      logger.e('Error getting token: $e');
      return null;
    }
  }

  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken().timeout(
        _tokenTimeout,
        onTimeout: () {
          logger.w('Timeout deleting FCM token');
        },
      );
      await _prefs.remove(_fcmTokenKey);
    } catch (e) {
      logger.e('Error deleting FCM token: $e');
      // Still try to remove from local storage
      try {
        await _prefs.remove(_fcmTokenKey);
      } catch (localError) {
        logger.e('Error removing token from local storage: $localError');
      }
    }
  }

  void dispose() {
    _tokenRefreshSubscription?.cancel();
    _foregroundMessageSubscription?.cancel();
    _tokenRefreshSubscription = null;
    _foregroundMessageSubscription = null;
    _isInitialized = false;
  }
}
