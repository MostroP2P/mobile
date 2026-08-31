import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mostro_mobile/services/encryption_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';

/// Image sanitizing (pure-Dart decode + re-encode: 1-5 s for a phone photo)
/// and whole-file ChaCha20-Poly1305 ran on the main isolate, freezing the UI
/// while sending or opening media. Both now run through Isolate.run; these
/// tests pin the async variants' behaviour, including error propagation
/// across the isolate boundary.
void main() {
  final key = Uint8List.fromList(List.generate(32, (i) => i));

  Uint8List tinyPng() {
    final image = img.Image(width: 2, height: 2);
    img.fill(image, color: img.ColorRgb8(200, 50, 50));
    return Uint8List.fromList(img.encodePng(image));
  }

  group('EncryptionService isolate variants', () {
    test('async blob roundtrip matches the sync implementation', () async {
      final plaintext = Uint8List.fromList(List.generate(1024, (i) => i % 251));

      final blob = await EncryptionService.encryptToBlobAsync(
        key: key,
        plaintext: plaintext,
      );
      final decrypted = await EncryptionService.decryptFromBlobAsync(
        key: key,
        blob: blob,
      );

      expect(decrypted, plaintext);
      // Cross-compatibility: sync decrypt reads the async-produced blob.
      expect(EncryptionService.decryptFromBlob(key: key, blob: blob),
          plaintext);
    });

    test('a tampered blob fails across the isolate boundary', () async {
      final blob = await EncryptionService.encryptToBlobAsync(
        key: key,
        plaintext: Uint8List.fromList([1, 2, 3]),
      );
      blob[blob.length - 1] ^= 0xFF;

      await expectLater(
        EncryptionService.decryptFromBlobAsync(key: key, blob: blob),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('MediaValidationService off the main isolate', () {
    test('light sanitization still validates and strips a PNG', () async {
      final result =
          await MediaValidationService.validateAndSanitizeImageLight(tinyPng());

      expect(result.mimeType, 'image/png');
      expect(result.width, 2);
      expect(result.height, 2);
      expect(img.decodePng(result.validatedData), isNotNull);
    });

    test('heavy sanitization still validates a PNG', () async {
      final result =
          await MediaValidationService.validateAndSanitizeImage(tinyPng());

      expect(result.mimeType, 'image/png');
      expect(img.decodePng(result.validatedData), isNotNull);
    });

    test('garbage input propagates the validation error', () async {
      await expectLater(
        MediaValidationService.validateAndSanitizeImageLight(
          Uint8List.fromList(List.filled(64, 7)),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}
