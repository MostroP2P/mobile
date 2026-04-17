import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/settings/settings.dart';

void main() {
  group('Session expiration settings', () {
    test('default settings have null sessionExpirationHours', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
      );
      expect(settings.sessionExpirationHours, isNull);
    });

    test('Config default is 720 hours (30 days)', () {
      expect(Config.sessionExpirationHours, 720);
    });

    test('null sessionExpirationHours falls back to Config default', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
      );
      final effectiveHours =
          settings.sessionExpirationHours ?? Config.sessionExpirationHours;
      expect(effectiveHours, 720);
    });

    test('sessionExpirationHours persists through copyWith', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        sessionExpirationHours: 168,
      );
      final updated = settings.copyWith(defaultFiatCode: 'USD');
      expect(updated.sessionExpirationHours, 168);
    });

    test('sessionExpirationHours can be updated via copyWith', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        sessionExpirationHours: 168,
      );
      final updated = settings.copyWith(sessionExpirationHours: 8760);
      expect(updated.sessionExpirationHours, 8760);
    });

    test('sessionExpirationHours can be cleared via copyWith', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        sessionExpirationHours: 168,
      );
      final updated = settings.copyWith(clearSessionExpiration: true);
      expect(updated.sessionExpirationHours, isNull);
    });

    test('zero means never (no cleanup)', () {
      final settings = Settings(
        relays: [],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        sessionExpirationHours: 0,
      );
      final isForever = (settings.sessionExpirationHours ?? Config.sessionExpirationHours) == 0;
      expect(isForever, isTrue);
    });

    test('serialization roundtrip preserves sessionExpirationHours', () {
      final settings = Settings(
        relays: ['wss://relay.test'],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
        sessionExpirationHours: 4320,
      );
      final json = settings.toJson();
      final restored = Settings.fromJson(json);
      expect(restored.sessionExpirationHours, 4320);
    });

    test('serialization roundtrip preserves null sessionExpirationHours', () {
      final settings = Settings(
        relays: ['wss://relay.test'],
        fullPrivacyMode: false,
        mostroPublicKey: 'test',
      );
      final json = settings.toJson();
      final restored = Settings.fromJson(json);
      expect(restored.sessionExpirationHours, isNull);
    });

    test('fromJson handles missing sessionExpirationHours (backward compat)', () {
      final json = {
        'relays': <String>[],
        'fullPrivacyMode': false,
        'mostroPublicKey': 'test',
      };
      final settings = Settings.fromJson(json);
      expect(settings.sessionExpirationHours, isNull);
    });

    test('all preset values are valid', () {
      const presets = [168, 720, 2160, 4320, 8760, 0];
      for (final hours in presets) {
        final settings = Settings(
          relays: [],
          fullPrivacyMode: false,
          mostroPublicKey: 'test',
          sessionExpirationHours: hours,
        );
        final json = settings.toJson();
        final restored = Settings.fromJson(json);
        expect(restored.sessionExpirationHours, hours);
      }
    });
  });
}
