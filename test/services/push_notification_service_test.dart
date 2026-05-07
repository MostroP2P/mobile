import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:mostro_mobile/services/push_notification_service.dart';

import '../mocks.mocks.dart';

class _FakeFcmService extends FCMService {
  _FakeFcmService(super.prefs, {this.tokenOverride = 'fake-fcm-token'});

  final String? tokenOverride;

  @override
  Future<String?> getToken() async => tokenOverride;
}

PushNotificationService _buildService({
  required MockClient httpClient,
  String? fcmToken = 'fake-fcm-token',
  String platform = 'android',
  bool? isPushEnabled,
}) {
  final service = PushNotificationService(
    fcmService: _FakeFcmService(
      MockSharedPreferencesAsync(),
      tokenOverride: fcmToken,
    ),
    pushServerUrl: 'https://push.example',
    httpClient: httpClient,
    isSupportedOverride: true,
    platformOverride: platform,
  );
  if (isPushEnabled != null) {
    service.isPushEnabledInSettings = () => isPushEnabled;
  }
  return service;
}

const _validPubkey =
    'a1b2c3d4e5f67890123456789012345678901234567890123456789012345abc';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PushNotificationService.notifyPeer', () {
    test('POSTs /api/notify with the trade_pubkey body', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response('{"accepted":true}', 202);
      });

      final service = _buildService(httpClient: mockClient);
      await service.notifyPeer(_validPubkey);

      expect(captured, isNotNull);
      expect(captured!.method, 'POST');
      expect(
        captured!.url.toString(),
        'https://push.example/api/notify',
      );
      expect(
        captured!.headers['content-type'],
        contains('application/json'),
      );
      final decoded = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(decoded.keys, ['trade_pubkey']);
      expect(decoded['trade_pubkey'], _validPubkey);
    });

    test('does not send sender_pubkey, signature, or auth headers', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        captured = request;
        return http.Response('{"accepted":true}', 202);
      });

      await _buildService(httpClient: mockClient).notifyPeer(_validPubkey);

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.containsKey('sender_pubkey'), isFalse);
      expect(body.containsKey('signature'), isFalse);
      expect(body.containsKey('idempotency_key'), isFalse);
      expect(captured!.headers.containsKey('authorization'), isFalse);
      expect(captured!.headers.containsKey('x-request-id'), isFalse);
    });

    test('swallows 400 responses without throwing', () async {
      final mockClient = MockClient((_) async => http.Response(
            '{"success":false,"message":"invalid"}',
            400,
          ));

      await expectLater(
        _buildService(httpClient: mockClient).notifyPeer('not-a-pubkey'),
        completes,
      );
    });

    test('swallows 429 rate-limit responses without retrying', () async {
      var calls = 0;
      final mockClient = MockClient((_) async {
        calls++;
        return http.Response(
          '{"success":false,"message":"rate limited"}',
          429,
          headers: {'retry-after': '12'},
        );
      });

      await _buildService(httpClient: mockClient).notifyPeer(_validPubkey);

      expect(calls, 1, reason: 'fire-and-forget must not retry on 429');
    });

    test('swallows network errors without throwing', () async {
      final mockClient = MockClient((_) async {
        throw const SocketExceptionLike();
      });

      await expectLater(
        _buildService(httpClient: mockClient).notifyPeer(_validPubkey),
        completes,
      );
    });

    test('returns early when push notifications are disabled in settings',
        () async {
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('{"accepted":true}', 202);
      });

      await _buildService(
        httpClient: mockClient,
        isPushEnabled: false,
      ).notifyPeer(_validPubkey);

      expect(called, isFalse);
    });

    test('returns early when platform is not supported', () async {
      var called = false;
      final mockClient = MockClient((_) async {
        called = true;
        return http.Response('{"accepted":true}', 202);
      });

      final service = PushNotificationService(
        fcmService: _FakeFcmService(MockSharedPreferencesAsync()),
        pushServerUrl: 'https://push.example',
        httpClient: mockClient,
        isSupportedOverride: false,
      );
      await service.notifyPeer(_validPubkey);

      expect(called, isFalse);
    });
  });

  group('PushNotificationService.registerToken', () {
    test('includes mostro_pubkey when callback returns a non-empty value',
        () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        captured = request;
        return http.Response(
          '{"success":true,"message":"ok","platform":"android"}',
          200,
        );
      });

      final service = _buildService(httpClient: mockClient);
      service.getMostroPubkey = () =>
          'deadbeef00000000000000000000000000000000000000000000000000000000';

      final ok = await service.registerToken(_validPubkey);

      expect(ok, isTrue);
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['trade_pubkey'], _validPubkey);
      expect(body['token'], 'fake-fcm-token');
      expect(body['platform'], 'android');
      expect(
        body['mostro_pubkey'],
        'deadbeef00000000000000000000000000000000000000000000000000000000',
      );
    });

    test('omits mostro_pubkey when callback is not set', () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        captured = request;
        return http.Response(
          '{"success":true,"message":"ok","platform":"android"}',
          200,
        );
      });

      final service = _buildService(httpClient: mockClient);
      // getMostroPubkey intentionally left null

      await service.registerToken(_validPubkey);

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.containsKey('mostro_pubkey'), isFalse);
    });

    test('omits mostro_pubkey when callback returns an empty string',
        () async {
      http.Request? captured;
      final mockClient = MockClient((request) async {
        if (request.url.path == '/api/health') {
          return http.Response('{"status":"ok"}', 200);
        }
        captured = request;
        return http.Response(
          '{"success":true,"message":"ok","platform":"android"}',
          200,
        );
      });

      final service = _buildService(httpClient: mockClient);
      service.getMostroPubkey = () => '';

      await service.registerToken(_validPubkey);

      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body.containsKey('mostro_pubkey'), isFalse);
    });
  });
}

// Used to simulate a transport failure inside MockClient without importing dart:io.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketExceptionLike';
}
