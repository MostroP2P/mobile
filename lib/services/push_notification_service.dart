import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:pointycastle/export.dart';

import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/services/fcm_service.dart';

final _logger = Logger();

/// Service for registering push notification tokens with the Mostro push server.
///
/// This implements a privacy-preserving approach following MIP-05:
/// - Device tokens are encrypted with the server's public key using ECDH + ChaCha20-Poly1305
/// - Server only knows the mapping trade_pubkey -> encrypted_device_token
/// - Server cannot see message content or user identity
/// - Probabilistic encryption ensures same token produces different ciphertexts
class PushNotificationService {
  final FCMService _fcmService;
  final String _pushServerUrl;

  String? _serverPubkey;
  bool _isInitialized = false;

  // Encryption constants
  static const int _paddedPayloadSize = 220;
  static const int _nonceSize = 12;
  static const int _pubkeySize = 33;

  // Platform identifiers for payload
  static const int _platformAndroid = 0x02;
  static const int _platformIos = 0x01;

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

  /// Initialize the service by fetching the server's public key
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    if (!isSupported) {
      debugPrint('PushService: Not supported on this platform');
      return false;
    }

    try {
      debugPrint('PushService: Fetching server public key...');

      final response = await http
          .get(Uri.parse('$_pushServerUrl/api/info'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _serverPubkey = data['server_pubkey'];

        if (_serverPubkey != null && _serverPubkey!.isNotEmpty) {
          _isInitialized = true;
          debugPrint('PushService: Initialized successfully');
          return true;
        } else {
          _logger.e('Server pubkey is null or empty');
          return false;
        }
      } else {
        _logger.e('Failed to get server info: ${response.statusCode}');
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

    if (!_isInitialized || _serverPubkey == null) {
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

      debugPrint(
          'PushService: Registering token for trade ${tradePubkey.substring(0, 16)}...');

      // Encrypt the token
      final encryptedToken = _encryptToken(fcmToken);
      if (encryptedToken == null) {
        _logger.e('Failed to encrypt token');
        return false;
      }

      // Send to server
      final response = await http
          .post(
            Uri.parse('$_pushServerUrl/api/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'trade_pubkey': tradePubkey,
              'encrypted_token': base64Encode(encryptedToken),
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          debugPrint(
              'PushService: Token registered for trade ${tradePubkey.substring(0, 16)}...');
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

  /// Unregister a device token for a specific trade
  Future<bool> unregisterToken(String tradePubkey) async {
    if (!isSupported) {
      return false;
    }

    try {
      debugPrint(
          'PushService: Unregistering token for trade ${tradePubkey.substring(0, 16)}...');

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
            'PushService: Token unregistered for trade ${tradePubkey.substring(0, 16)}...');
        return true;
      }

      _logger.w('Failed to unregister token: ${response.body}');
      return false;
    } catch (e) {
      _logger.e('Error unregistering token: $e');
      return false;
    }
  }

  /// Encrypt a device token using the server's public key
  ///
  /// Format: ephemeral_pubkey (33 bytes) || nonce (12 bytes) || ciphertext
  /// Following MIP-05 encryption scheme:
  /// 1. Generate ephemeral keypair
  /// 2. ECDH with server's public key
  /// 3. HKDF to derive encryption key
  /// 4. ChaCha20-Poly1305 encryption with padded payload
  Uint8List? _encryptToken(String deviceToken) {
    if (_serverPubkey == null) return null;

    try {
      final random = Random.secure();

      // Parse server public key (compressed, 33 bytes)
      final serverPubkeyBytes = _hexToBytes(_serverPubkey!);

      // Generate ephemeral keypair
      final ecParams = ECDomainParameters('secp256k1');
      final keyGen = ECKeyGenerator()
        ..init(ParametersWithRandom(
          ECKeyGeneratorParameters(ecParams),
          SecureRandom('Fortuna')..seed(KeyParameter(_randomBytes(32, random))),
        ));

      final ephemeralKeyPair = keyGen.generateKeyPair();
      final ephemeralPrivate = ephemeralKeyPair.privateKey as ECPrivateKey;
      final ephemeralPublic = ephemeralKeyPair.publicKey as ECPublicKey;

      // Get compressed ephemeral public key (33 bytes)
      final ephemeralPubkeyBytes = _compressPublicKey(ephemeralPublic.Q!);

      // Parse server public key as EC point
      final serverPoint = ecParams.curve.decodePoint(serverPubkeyBytes);

      // ECDH: shared_point = ephemeral_private * server_public
      final sharedPoint = serverPoint! * ephemeralPrivate.d;
      final sharedX = _bigIntToBytes(sharedPoint!.x!.toBigInteger()!, 32);

      // HKDF to derive encryption key
      final encryptionKey = _hkdfDerive(sharedX, 32);

      // Generate random nonce
      final nonce = _randomBytes(_nonceSize, random);

      // Create padded payload
      final paddedPayload = _createPaddedPayload(deviceToken, random);

      // Encrypt with ChaCha20-Poly1305
      final cipher = ChaCha20Poly1305(ChaCha7539Engine(), Poly1305());
      cipher.init(
        true,
        AEADParameters(
          KeyParameter(encryptionKey),
          128, // 16 bytes auth tag
          nonce,
          Uint8List(0), // no AAD
        ),
      );

      final ciphertext = cipher.process(paddedPayload);

      // Combine: ephemeral_pubkey || nonce || ciphertext
      final result = Uint8List(_pubkeySize + _nonceSize + ciphertext.length);
      result.setRange(0, _pubkeySize, ephemeralPubkeyBytes);
      result.setRange(_pubkeySize, _pubkeySize + _nonceSize, nonce);
      result.setRange(_pubkeySize + _nonceSize, result.length, ciphertext);

      return result;
    } catch (e) {
      _logger.e('Encryption error: $e');
      return null;
    }
  }

  /// Create padded payload: platform_byte || token_length (2 bytes BE) || token || random_padding
  Uint8List _createPaddedPayload(String deviceToken, Random random) {
    final tokenBytes = utf8.encode(deviceToken);
    final platformByte = Platform.isIOS ? _platformIos : _platformAndroid;

    final payload = Uint8List(_paddedPayloadSize);
    payload[0] = platformByte;
    payload[1] = (tokenBytes.length >> 8) & 0xFF;
    payload[2] = tokenBytes.length & 0xFF;
    payload.setRange(3, 3 + tokenBytes.length, tokenBytes);

    // Fill rest with random padding
    final paddingStart = 3 + tokenBytes.length;
    for (var i = paddingStart; i < _paddedPayloadSize; i++) {
      payload[i] = random.nextInt(256);
    }

    return payload;
  }

  /// HKDF-SHA256 key derivation
  Uint8List _hkdfDerive(Uint8List ikm, int length) {
    const salt = 'mostro-push-v1';
    const info = 'mostro-token-encryption';

    final hmac = HMac(SHA256Digest(), 64);

    // Extract
    hmac.init(KeyParameter(Uint8List.fromList(utf8.encode(salt))));
    final prk = Uint8List(32);
    hmac.update(ikm, 0, ikm.length);
    hmac.doFinal(prk, 0);

    // Expand
    hmac.init(KeyParameter(prk));
    final infoBytes = Uint8List.fromList(utf8.encode(info));
    final okm = Uint8List(length);

    final t = Uint8List(32 + infoBytes.length + 1);
    t.setRange(0, infoBytes.length, infoBytes);
    t[infoBytes.length] = 1;

    hmac.update(t, 0, infoBytes.length + 1);
    hmac.doFinal(okm, 0);

    return okm.sublist(0, length);
  }

  // Helper methods for byte manipulation

  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < hex.length; i += 2) {
      result[i ~/ 2] = int.parse(hex.substring(i, i + 2), radix: 16);
    }
    return result;
  }

  Uint8List _randomBytes(int length, Random random) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  Uint8List _bigIntToBytes(BigInt value, int length) {
    final bytes = Uint8List(length);
    var v = value;
    for (var i = length - 1; i >= 0; i--) {
      bytes[i] = (v & BigInt.from(0xFF)).toInt();
      v = v >> 8;
    }
    return bytes;
  }

  Uint8List _compressPublicKey(ECPoint point) {
    final x = _bigIntToBytes(point.x!.toBigInteger()!, 32);
    final yIsOdd = point.y!.toBigInteger()!.isOdd;
    final compressed = Uint8List(33);
    compressed[0] = yIsOdd ? 0x03 : 0x02;
    compressed.setRange(1, 33, x);
    return compressed;
  }
}
