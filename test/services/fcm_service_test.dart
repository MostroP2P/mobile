import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/services/fcm_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// An initialized FCMService whose Firebase answer the test controls.
class _FcmWithFirebase extends FCMService {
  _FcmWithFirebase(super.prefs, this.fetch);

  final Future<String?> Function() fetch;

  @override
  bool get isInitialized => true;

  // `async` keeps the result a Future<String?>, as the Firebase plugin's is.
  @override
  Future<String?> fetchFirebaseToken() async => fetch();
}

void main() {
  late SharedPreferencesAsync prefs;

  setUp(() async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    await prefs.setString('fcm_token', 'stored-token');
  });

  group('FCMService.getToken', () {
    test('prefers the token Firebase holds now and stores it', () async {
      final fcm = _FcmWithFirebase(prefs, () async => 'rotated-token');

      expect(await fcm.getToken(), 'rotated-token');
      expect(await prefs.getString('fcm_token'), 'rotated-token');
    });

    test('falls back to the stored token when Firebase has none', () async {
      final fcm = _FcmWithFirebase(prefs, () async => null);

      expect(await fcm.getToken(), 'stored-token');
    });

    test('falls back to the stored token when Firebase fails', () async {
      final fcm = _FcmWithFirebase(
        prefs,
        () async => throw Exception('Play Services unavailable'),
      );

      expect(await fcm.getToken(), 'stored-token');
    });

    test('does not ask Firebase before it is initialized', () async {
      var asked = false;
      final fcm = _UninitializedFcm(prefs, () => asked = true);

      expect(await fcm.getToken(), 'stored-token');
      expect(asked, isFalse);
    });
  });
}

class _UninitializedFcm extends FCMService {
  _UninitializedFcm(super.prefs, this.onFetch);

  final void Function() onFetch;

  @override
  Future<String?> fetchFirebaseToken() async {
    onFetch();
    return 'unexpected';
  }
}
