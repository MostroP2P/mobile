import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/services/fcm_service.dart';

final _logger = Logger();

/// Safely truncate a pubkey for logging, avoiding RangeError on short strings.
String _shortenPubkey(String pubkey, [int maxLength = 16]) {
  if (pubkey.length <= maxLength) return pubkey;
  return '${pubkey.substring(0, maxLength)}...';
}

/// Service for registering push notification tokens with the Mostro push server.
///
/// Current implementation: Plaintext token registration (Phase 3)
/// - Device tokens are sent over HTTPS (encrypted in transit)
/// - Server stores mapping: trade_pubkey -> device_token
///
/// Future implementation: Encrypted token registration (Phase 5)
/// - Will add ECDH + ChaCha20-Poly1305 encryption for privacy-preserving tokens
class PushNotificationService {
  final FCMService _fcmService;
  final String _pushServerUrl;

  bool _isInitialized = false;

  /// Track registered trade pubkeys for re-registration on token refresh
  final Set<String> _registeredTradePubkeys = {};

  /// Callback to check if push notifications are enabled in settings
  /// Set this from the app to integrate with user preferences
  bool Function()? isPushEnabledInSettings;

  PushNotificationService({
    required FCMService fcmService,
    String? pushServerUrl,
  })  : _fcmService = fcmService,
        _pushServerUrl = pushServerUrl ?? Config.pushServerUrl;

  /// Check if push notifications are supported on this platform
  bool get isSupported {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  bool get isInitialized => _isInitialized;

  /// Get the current platform identifier
  String get _platform => Platform.isIOS ? 'ios' : 'android';

  /// Initialize the service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (!isSupported) {
      debugPrint('PushService: Not supported on this platform');
      return false;
    }

    try {
      debugPrint('PushService: Checking server health...');

      final response = await http
          .get(Uri.parse('$_pushServerUrl/api/health'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        _isInitialized = true;
        debugPrint('PushService: Initialized successfully');
        return true;
      } else {
        _logger.e('Server health check failed: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      _logger.e('Failed to initialize push service: $e');
      return false;
    }
  }

  /// Register a device token for a specific trade
  ///
  /// [tradePubkey] - The public key of the trade (hex, 64 chars)
  /// This is the key that Mostro daemon uses in the 'p' tag when sending events
  Future<bool> registerToken(String tradePubkey) async {
    if (!isSupported) {
      return false;
    }

    // Check if push notifications are enabled in settings
    if (isPushEnabledInSettings != null && !isPushEnabledInSettings!()) {
      debugPrint('PushService: Push notifications disabled in settings, skipping registration');
      return false;
    }

    if (!_isInitialized) {
      _logger.w('Push service not initialized');
      final initialized = await initialize();
      if (!initialized) return false;
    }

    try {
      // Get FCM token from FCMService
      final fcmToken = await _fcmService.getToken();
      if (fcmToken == null) {
        _logger.w('FCM token is null, cannot register');
        return false;
      }

      debugPrint('PushService: Registering token for trade ${_shortenPubkey(tradePubkey)}');

      // Send plaintext token to server (Phase 3 - unencrypted)
      final response = await http
          .post(
            Uri.parse('$_pushServerUrl/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trade_pubkey': tradePubkey,
              'token': fcmToken,
              'platform': _platform,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint(
              'PushService: Token registered for trade ${_shortenPubkey(tradePubkey)}');
          _registeredTradePubkeys.add(tradePubkey);
          return true;
        }
      }

      _logger.e('Failed to register token: ${response.body}');
      return false;
    } catch (e) {
      _logger.e('Error registering token: $e');
      return false;
    }
  }

  /// Re-register all known trade pubkeys with the new FCM token.
  /// Called when FCM token is refreshed.
  Future<void> reRegisterAllTokens() async {
    if (_registeredTradePubkeys.isEmpty) {
      debugPrint('PushService: No trade pubkeys to re-register');
      return;
    }

    debugPrint(
        'PushService: Re-registering ${_registeredTradePubkeys.length} trade pubkeys...');

    // Copy the set to avoid modification during iteration
    final pubkeys = Set<String>.from(_registeredTradePubkeys);
    for (final tradePubkey in pubkeys) {
      try {
        await registerToken(tradePubkey);
      } catch (e) {
        _logger.e('Error re-registering token for $tradePubkey: $e');
      }
    }
  }

  /// Unregister all registered tokens
  /// Called when user disables push notifications in settings
  Future<void> unregisterAllTokens() async {
    if (!isSupported || _registeredTradePubkeys.isEmpty) {
      return;
    }

    debugPrint(
        'PushService: Unregistering all ${_registeredTradePubkeys.length} tokens...');

    // Copy the set to avoid modification during iteration
    final pubkeys = Set<String>.from(_registeredTradePubkeys);
    for (final tradePubkey in pubkeys) {
      try {
        await unregisterToken(tradePubkey);
      } catch (e) {
        _logger.e('Error unregistering token for $tradePubkey: $e');
      }
    }
  }

  /// Unregister a device token for a specific trade
  Future<bool> unregisterToken(String tradePubkey) async {
    if (!isSupported) {
      return false;
    }

    try {
      debugPrint(
          'PushService: Unregistering token for trade ${_shortenPubkey(tradePubkey)}');

      final response = await http
          .post(
            Uri.parse('$_pushServerUrl/api/unregister'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trade_pubkey': tradePubkey,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        debugPrint(
            'PushService: Token unregistered for trade ${_shortenPubkey(tradePubkey)}');
        _registeredTradePubkeys.remove(tradePubkey);
        return true;
      }

      _logger.w('Failed to unregister token: ${response.body}');
      return false;
    } catch (e) {
      _logger.e('Error unregistering token: $e');
      return false;
    }
  }
}
