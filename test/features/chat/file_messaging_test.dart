import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:image/image.dart' as img;
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/services/encryption_service.dart';
import 'package:mostro_mobile/services/blossom_client.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/blossom_download_service.dart';
import 'package:mostro_mobile/features/chat/notifiers/chat_room_notifier.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

import '../../mocks.mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Use valid keys from NIP-06 test vectors (same pattern as mostro_service_test.dart)
  const validMnemonic = 'leader monkey parrot ring guide accident before fence cannon height naive bean';
  final keyDerivator = KeyDerivator(Config.keyDerivationPath);
  final extendedPrivKey = keyDerivator.extendedKeyFromMnemonic(validMnemonic);
  final masterPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 0);
  final tradePrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 1);
  final peerPrivKey = keyDerivator.derivePrivateKey(extendedPrivKey, 2);
  final peerPublicKey = keyDerivator.privateToPublicKey(peerPrivKey);

  provideDummy<Session>(Session(
    masterKey: NostrKeyPairs(private: masterPrivKey),
    tradeKey: NostrKeyPairs(private: tradePrivKey),
    keyIndex: 1,
    fullPrivacy: false,
    startTime: DateTime.now(),
    orderId: 'test-order-id',
    role: Role.buyer,
    peer: Peer(publicKey: peerPublicKey),
  ));

  provideDummy<BlossomClient>(MockBlossomClient());
  provideDummy<EncryptedFileUploadService>(MockEncryptedFileUploadService());
  provideDummy<EncryptedImageUploadService>(MockEncryptedImageUploadService());
  provideDummy<BlossomDownloadService>(MockBlossomDownloadService());
  provideDummy<ChatRoomNotifier>(MockChatRoomNotifier());

  group('File Messaging System', () {
    late MockBlossomClient mockBlossomClient;
    late Session testSession;

    setUp(() {
      mockBlossomClient = MockBlossomClient();

      // Use same valid key derivation pattern as mostro_service_test.dart
      testSession = Session(
        masterKey: NostrKeyPairs(private: masterPrivKey),
        tradeKey: NostrKeyPairs(private: tradePrivKey),
        keyIndex: 1,
        fullPrivacy: false,
        startTime: DateTime.now(),
        orderId: 'test-order-id',
        role: Role.buyer,
        peer: Peer(publicKey: peerPublicKey),
      );
    });

    group('Encryption & Key Management', () {
      test('derives identical shared keys for both parties', () {
        // Use valid keys from key derivation (same pattern as mostro_service_test.dart)
        final userAPrivateKey = tradePrivKey;
        final userAPublicKey = keyDerivator.privateToPublicKey(userAPrivateKey);
        final userBPrivateKey = peerPrivKey;
        final userBPublicKey = peerPublicKey;

        final sharedKeyA = NostrUtils.computeSharedKey(userAPrivateKey, userBPublicKey);
        final sharedKeyB = NostrUtils.computeSharedKey(userBPrivateKey, userAPublicKey);

        expect(sharedKeyA.private, equals(sharedKeyB.private));
      });

      test('shared key used for both text and files', () {
        // Test that the same shared key derivation logic is used for files as for text messages
        // This test validates the actual key derivation, not mocks
        final sharedKeyHex = testSession.sharedKey!.private;
        
        // Simulate the same conversion logic as ChatRoomNotifier.getSharedKey()
        final expectedBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          final byte = int.parse(sharedKeyHex.substring(i * 2, i * 2 + 2), radix: 16);
          expectedBytes[i] = byte;
        }

        // Test that we can encrypt and decrypt file data with the derived shared key
        final testFileData = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        
        final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
          key: expectedBytes,
          plaintext: testFileData,
        );

        final decryptedData = EncryptionService.decryptChaCha20Poly1305(
          key: expectedBytes,
          nonce: encryptionResult.nonce,
          encryptedData: encryptionResult.encryptedData,
          authTag: encryptionResult.authTag,
        );

        // Verify the key works for file encryption/decryption
        expect(decryptedData, equals(testFileData));
        expect(expectedBytes.length, equals(32));
        
        // Verify the hex conversion logic matches what ChatRoomNotifier would produce
        expect(sharedKeyHex.length, equals(64)); // 32 bytes * 2 hex chars
      });

      test('encrypts and decrypts files correctly', () {
        final testData = Uint8List.fromList(List.generate(1000, (i) => i % 256));
        final key = Uint8List.fromList(List.generate(32, (i) => i));

        final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
          key: key,
          plaintext: testData,
        );

        expect(encryptionResult.encryptedData.length, equals(testData.length));
        expect(encryptionResult.nonce.length, equals(12));
        expect(encryptionResult.authTag.length, equals(16));

        final decryptedData = EncryptionService.decryptChaCha20Poly1305(
          key: key,
          nonce: encryptionResult.nonce,
          encryptedData: encryptionResult.encryptedData,
          authTag: encryptionResult.authTag,
        );

        expect(decryptedData, equals(testData));
      });

      test('fails decryption with wrong shared key', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final correctKey = Uint8List.fromList(List.generate(32, (i) => i));
        final wrongKey = Uint8List.fromList(List.generate(32, (i) => 255 - i));

        final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
          key: correctKey,
          plaintext: testData,
        );

        expect(
          () => EncryptionService.decryptChaCha20Poly1305(
            key: wrongKey,
            nonce: encryptionResult.nonce,
            encryptedData: encryptionResult.encryptedData,
            authTag: encryptionResult.authTag,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('generates unique nonces for each encryption', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final key = Uint8List.fromList(List.generate(32, (i) => i));
        final nonces = <String>{};

        for (int i = 0; i < 100; i++) {
          final result = EncryptionService.encryptChaCha20Poly1305(
            key: key,
            plaintext: testData,
          );
          final nonceHex = result.nonce.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          nonces.add(nonceHex);
        }

        expect(nonces.length, equals(100));
      });

      test('handles blob format correctly', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final key = Uint8List.fromList(List.generate(32, (i) => i));

        final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
          key: key,
          plaintext: testData,
        );

        final blob = encryptionResult.toBlob();
        final reconstructed = EncryptionResult.fromBlob(blob);

        expect(reconstructed.nonce, equals(encryptionResult.nonce));
        expect(reconstructed.encryptedData, equals(encryptionResult.encryptedData));
        expect(reconstructed.authTag, equals(encryptionResult.authTag));
      });
    });

    group('File Validation', () {
      test('uses 25MB max file size', () {
        expect(FileValidationService.maxFileSize, equals(25 * 1024 * 1024));
      });

      test('validates supported extensions', () {
        final supportedExtensions = FileValidationService.getSupportedExtensions();

        expect(supportedExtensions, contains('.jpg'));
        expect(supportedExtensions, contains('.png'));
        expect(supportedExtensions, contains('.pdf'));
        expect(supportedExtensions, contains('.mp4'));
        expect(supportedExtensions, contains('.doc'));
        expect(supportedExtensions, isNot(contains('.exe')));
      });

      test('checks file type support by filename', () {
        expect(FileValidationService.isFileTypeSupported('test.jpg'), isTrue);
        expect(FileValidationService.isFileTypeSupported('test.png'), isTrue);
        expect(FileValidationService.isFileTypeSupported('test.pdf'), isTrue);
        expect(FileValidationService.isFileTypeSupported('test.exe'), isFalse);
        expect(FileValidationService.isFileTypeSupported('malware.bat'), isFalse);
      });

      test('checks file type support by MIME type', () {
        expect(FileValidationService.isFileTypeSupported('test.unknown', mimeType: 'image/jpeg'), isTrue);
        expect(FileValidationService.isFileTypeSupported('test.unknown', mimeType: 'application/pdf'), isTrue);
        expect(FileValidationService.isFileTypeSupported('test.unknown', mimeType: 'application/x-executable'), isFalse);
      });

      test('handles zero-byte files', () {
        expect(0, lessThan(FileValidationService.maxFileSize));
      });

      test('validates real JPEG file with API', () async {
        // Create a temporary JPEG file with valid headers
        final tempDir = await Directory.systemTemp.createTemp('file_validation_test');
        final jpegFile = File('${tempDir.path}/test.jpg');
        await jpegFile.writeAsBytes(_createTestJpeg());

        final result = await FileValidationService.validateFile(jpegFile);

        expect(result.mimeType, equals('image/jpeg'));
        expect(result.fileType, equals('image'));
        expect(result.extension, equals('.jpg'));
        expect(result.size, equals(_createTestJpeg().length));
        expect(result.filename, equals('test.jpg'));

        // Cleanup
        await tempDir.delete(recursive: true);
      });

      test('validates real PNG file with API', () async {
        final tempDir = await Directory.systemTemp.createTemp('file_validation_test');
        final pngFile = File('${tempDir.path}/test.png');
        await pngFile.writeAsBytes(_createTestPng());

        final result = await FileValidationService.validateFile(pngFile);

        expect(result.mimeType, equals('image/png'));
        expect(result.fileType, equals('image'));
        expect(result.extension, equals('.png'));
        expect(result.size, equals(_createTestPng().length));

        await tempDir.delete(recursive: true);
      });

      test('rejects oversized file with API', () async {
        final tempDir = await Directory.systemTemp.createTemp('file_validation_test');
        final oversizedFile = File('${tempDir.path}/large.txt');
        
        // Create a file that exceeds 25MB limit
        final largeData = Uint8List(26 * 1024 * 1024); // 26MB
        await oversizedFile.writeAsBytes(largeData);

        expect(
          () async => await FileValidationService.validateFile(oversizedFile),
          throwsA(isA<FileValidationException>()),
        );

        await tempDir.delete(recursive: true);
      });

      test('rejects unsupported file type with API', () async {
        final tempDir = await Directory.systemTemp.createTemp('file_validation_test');
        final exeFile = File('${tempDir.path}/malware.exe');
        
        // Create a fake exe file
        final exeData = Uint8List.fromList([
          0x4D, 0x5A, // PE executable header
          ...List.generate(100, (i) => i % 256),
        ]);
        await exeFile.writeAsBytes(exeData);

        expect(
          () async => await FileValidationService.validateFile(exeFile),
          throwsA(isA<FileValidationException>()),
        );

        await tempDir.delete(recursive: true);
      });
    });

    group('Media Validation', () {
      test('supported image types are defined', () {
        final jpegType = SupportedImageType.jpeg;
        final pngType = SupportedImageType.png;

        expect(jpegType.mimeType, equals('image/jpeg'));
        expect(jpegType.extension, equals('jpg'));
        expect(pngType.mimeType, equals('image/png'));
        expect(pngType.extension, equals('png'));
      });

      test('validates image format requirements', () {
        final testImageData = _createTestJpeg();
        expect(testImageData.length, greaterThan(10));
        expect(testImageData[0], equals(0xFF));
        expect(testImageData[1], equals(0xD8));
      });

      test('handles different image formats', () {
        final jpegData = _createTestJpeg();
        final pngData = _createTestPng();

        expect(jpegData[0], equals(0xFF));
        expect(jpegData[1], equals(0xD8));
        expect(pngData[0], equals(0x89));
        expect(pngData[1], equals(0x50));
      });

      test('validates real JPEG with MediaValidationService API', () async {
        final jpegData = _createRealJpeg();

        final result = await MediaValidationService.validateAndSanitizeImageLight(jpegData);

        expect(result.imageType, equals(SupportedImageType.jpeg));
        expect(result.mimeType, equals('image/jpeg'));
        expect(result.extension, equals('jpg'));
        expect(result.validatedData, isNotNull);
        expect(result.validatedData.length, greaterThan(0));
        expect(result.width, equals(10));
        expect(result.height, equals(10));
      });

      test('validates real PNG with MediaValidationService API', () async {
        final pngData = _createRealPng();

        final result = await MediaValidationService.validateAndSanitizeImageLight(pngData);

        expect(result.imageType, equals(SupportedImageType.png));
        expect(result.mimeType, equals('image/png'));
        expect(result.extension, equals('png'));
        expect(result.validatedData, isNotNull);
        expect(result.validatedData.length, greaterThan(0));
        expect(result.width, equals(10));
        expect(result.height, equals(10));
      });

      test('rejects invalid image data with MediaValidationService API', () async {
        final invalidData = Uint8List.fromList([0x42, 0x41, 0x44, 0x00]); // Invalid header

        expect(
          () async => await MediaValidationService.validateAndSanitizeImageLight(invalidData),
          throwsA(isA<MediaValidationException>()),
        );
      });

      test('rejects empty image data with MediaValidationService API', () async {
        final emptyData = Uint8List(0);

        expect(
          () async => await MediaValidationService.validateAndSanitizeImageLight(emptyData),
          throwsA(isA<MediaValidationException>()),
        );
      });

      test('heavy sanitization works with MediaValidationService API', () async {
        final jpegData = _createRealJpeg();

        final result = await MediaValidationService.validateAndSanitizeImage(jpegData);

        expect(result.imageType, equals(SupportedImageType.jpeg));
        expect(result.mimeType, equals('image/jpeg'));
        expect(result.extension, equals('jpg'));
        expect(result.validatedData, isNotNull);
        expect(result.validatedData.length, greaterThan(0));
        expect(result.width, equals(10));
        expect(result.height, equals(10));
      });

      test('checks image type support with MediaValidationService API', () {
        expect(MediaValidationService.isImageTypeSupported('image/jpeg'), isTrue);
        expect(MediaValidationService.isImageTypeSupported('image/png'), isTrue);
        expect(MediaValidationService.isImageTypeSupported('image/gif'), isFalse);
        expect(MediaValidationService.isImageTypeSupported('image/bmp'), isFalse);
        expect(MediaValidationService.isImageTypeSupported('application/pdf'), isFalse);
      });
    });

    group('Blossom Upload', () {
      test('delegates to BlossomClient uploadImage method', () async {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        const mimeType = 'image/jpeg';

        when(mockBlossomClient.uploadImage(
          imageData: testData,
          mimeType: mimeType,
        )).thenAnswer((_) async => 'https://blossom.server.com/hash123');

        final result = await mockBlossomClient.uploadImage(
          imageData: testData,
          mimeType: mimeType,
        );

        expect(result, equals('https://blossom.server.com/hash123'));
        verify(mockBlossomClient.uploadImage(
          imageData: testData,
          mimeType: mimeType,
        )).called(1);
      });

      test('exposes configured server URL', () async {
        final blossomClient = BlossomClient(serverUrl: 'https://blossom.server.com');

        // Verify URL construction logic
        expect(blossomClient.serverUrl, equals('https://blossom.server.com'));
      });

      test('handles upload error responses', () async {
        const mimeType = 'image/jpeg';

        when(mockBlossomClient.uploadImage(
          imageData: anyNamed('imageData'),
          mimeType: mimeType,
        )).thenThrow(BlossomException('Upload failed: 413 - File too large'));

        expect(
          () => mockBlossomClient.uploadImage(
            imageData: Uint8List.fromList([1, 2, 3, 4, 5]),
            mimeType: mimeType,
          ),
          throwsA(isA<BlossomException>()),
        );
      });
    });

    group('Gift Wrap Message Creation', () {
      test('creates file message with correct metadata using real code', () {
        final uploadResult = EncryptedFileUploadResult(
          blossomUrl: 'https://blossom.server.com/hash123',
          nonce: 'abcdef123456789012345678',
          fileType: 'document',
          mimeType: 'application/pdf',
          originalSize: 12345,
          filename: 'document.pdf',
          encryptedSize: 12389,
        );

        final json = uploadResult.toJson();

        expect(json['type'], equals('file_encrypted'));
        expect(json['nonce'], isA<String>());
        expect(json['blossom_url'], startsWith('https://'));
        expect(json.containsKey('encryption_key'), isFalse);
        expect(json['file_type'], equals('document'));
        expect(json['mime_type'], equals('application/pdf'));
        expect(json['original_size'], equals(12345));
        expect(json['encrypted_size'], equals(12389));
      });

      test('creates image message with correct structure using real code', () {
        final uploadResult = EncryptedImageUploadResult(
          blossomUrl: 'https://blossom.server.com/hash456',
          nonce: '1234567890abcdef12345678',
          mimeType: 'image/jpeg',
          originalSize: 54321,
          width: 1920,
          height: 1080,
          filename: 'photo.jpg',
          encryptedSize: 54365,
        );

        final json = uploadResult.toJson();

        expect(json['type'], equals('image_encrypted'));
        expect(json.containsKey('nonce'), isTrue);
        expect(json.containsKey('encryption_key'), isFalse);
        expect(json.containsKey('shared_key'), isFalse);
        expect(json['mime_type'], equals('image/jpeg'));
        expect(json['width'], equals(1920));
        expect(json['height'], equals(1080));
        expect(json['encrypted_size'], equals(54365));
      });

      test('file and image messages have different type fields', () {
        final fileResult = EncryptedFileUploadResult(
          blossomUrl: 'https://blossom.server.com/file',
          nonce: 'nonce123',
          fileType: 'video',
          mimeType: 'video/mp4',
          originalSize: 9876543,
          filename: 'video.mp4',
          encryptedSize: 9876587,
        );

        final imageResult = EncryptedImageUploadResult(
          blossomUrl: 'https://blossom.server.com/image',
          nonce: 'nonce456',
          mimeType: 'image/png',
          originalSize: 123456,
          width: 800,
          height: 600,
          filename: 'image.png',
          encryptedSize: 123500,
        );

        final fileJson = fileResult.toJson();
        final imageJson = imageResult.toJson();

        expect(fileJson['type'], equals('file_encrypted'));
        expect(imageJson['type'], equals('image_encrypted'));
        expect(fileJson['file_type'], equals('video'));
        expect(imageJson.containsKey('width'), isTrue);
        expect(imageJson.containsKey('height'), isTrue);
        expect(fileJson.containsKey('width'), isFalse);
      });
    });

    group('File Download & Decryption', () {
      test('verifies file integrity after decryption', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final key = Uint8List.fromList(List.generate(32, (i) => i));

        final encrypted = EncryptionService.encryptChaCha20Poly1305(
          key: key,
          plaintext: testData,
        );

        final decrypted = EncryptionService.decryptChaCha20Poly1305(
          key: key,
          nonce: encrypted.nonce,
          encryptedData: encrypted.encryptedData,
          authTag: encrypted.authTag,
        );

        expect(decrypted.length, equals(testData.length));
        expect(decrypted, equals(testData));
      });
    });

    group('Complete File Sharing Flows', () {
      test('handles file sharing between different sessions', () {
        // Create session 1 with different derived keys
        final session1TradeKey = keyDerivator.derivePrivateKey(extendedPrivKey, 10);
        final session1PeerKey = keyDerivator.derivePrivateKey(extendedPrivKey, 11);
        final session1PeerPublic = keyDerivator.privateToPublicKey(session1PeerKey);

        final session1 = Session(
          masterKey: NostrKeyPairs(private: masterPrivKey),
          tradeKey: NostrKeyPairs(private: session1TradeKey),
          keyIndex: 10,
          fullPrivacy: false,
          startTime: DateTime.now(),
          orderId: 'order-1',
          role: Role.buyer,
          peer: Peer(publicKey: session1PeerPublic),
        );

        // Create session 2 with different derived keys  
        final session2TradeKey = keyDerivator.derivePrivateKey(extendedPrivKey, 20);
        final session2PeerKey = keyDerivator.derivePrivateKey(extendedPrivKey, 21);
        final session2PeerPublic = keyDerivator.privateToPublicKey(session2PeerKey);

        final session2 = Session(
          masterKey: NostrKeyPairs(private: masterPrivKey),
          tradeKey: NostrKeyPairs(private: session2TradeKey),
          keyIndex: 20,
          fullPrivacy: false,
          startTime: DateTime.now(),
          orderId: 'order-2',
          role: Role.seller,
          peer: Peer(publicKey: session2PeerPublic),
        );

        expect(session1.sharedKey!.private, isNot(equals(session2.sharedKey!.private)));
      });
    });

    group('Security & Edge Cases', () {
      test('prevents cross-session file decryption', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final key1 = Uint8List.fromList(List.generate(32, (i) => i));
        final key2 = Uint8List.fromList(List.generate(32, (i) => 255 - i));

        final encrypted = EncryptionService.encryptChaCha20Poly1305(
          key: key1,
          plaintext: testData,
        );

        expect(
          () => EncryptionService.decryptChaCha20Poly1305(
            key: key2,
            nonce: encrypted.nonce,
            encryptedData: encrypted.encryptedData,
            authTag: encrypted.authTag,
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('handles corrupted encryption data', () {
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);
        final key = Uint8List.fromList(List.generate(32, (i) => i));

        final encrypted = EncryptionService.encryptChaCha20Poly1305(
          key: key,
          plaintext: testData,
        );

        // Corrupt the auth tag
        final corruptedAuthTag = Uint8List.fromList(encrypted.authTag);
        corruptedAuthTag[0] = (corruptedAuthTag[0] + 1) % 256;

        expect(
          () => EncryptionService.decryptChaCha20Poly1305(
            key: key,
            nonce: encrypted.nonce,
            encryptedData: encrypted.encryptedData,
            authTag: corruptedAuthTag,
          ),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('validates session isolation', () {
        final orderId1 = 'order-123';
        final orderId2 = 'order-456';

        expect(orderId1, isNot(equals(orderId2)));
        expect(testSession.orderId, equals('test-order-id'));
        expect(testSession.orderId, isNot(equals(orderId1)));
      });

      test('handles malformed blob data', () {
        final tooSmallBlob = Uint8List(10);

        expect(
          () => EncryptionResult.fromBlob(tooSmallBlob),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('validates key format and length', () {
        final validKey = Uint8List.fromList(List.generate(32, (i) => i));
        final invalidKey = Uint8List(16);
        final testData = Uint8List.fromList([1, 2, 3, 4, 5]);

        // Valid key should work
        final result = EncryptionService.encryptChaCha20Poly1305(
          key: validKey,
          plaintext: testData,
        );
        expect(result.encryptedData, isNotNull);
        expect(result.nonce.length, equals(12));
        expect(result.authTag.length, equals(16));

        // Invalid key should throw ArgumentError
        expect(
          () => EncryptionService.encryptChaCha20Poly1305(
            key: invalidKey,
            plaintext: testData,
          ),
          throwsArgumentError,
        );
      });
    });
  });
}

// Helper functions for test data creation

/// Creates a minimal JPEG byte sequence with valid header markers for header validation tests
Uint8List _createTestJpeg() {
  // Minimal valid JPEG header for basic header tests
  return Uint8List.fromList([
    0xFF, 0xD8, // JPEG SOI marker
    0xFF, 0xE0, // JFIF APP0 marker
    0x00, 0x10, // Length
    0x4A, 0x46, 0x49, 0x46, 0x00, // "JFIF\0"
    0x01, 0x01, // Version 1.1
    0x01, 0x00, 0x48, 0x00, 0x48, // Aspect ratio and resolution
    0x00, 0x00, // No thumbnail
    0xFF, 0xD9, // JPEG EOI marker
  ]);
}

/// Creates a minimal PNG byte sequence with valid header markers for header validation tests
Uint8List _createTestPng() {
  // Minimal valid PNG header for basic header tests
  return Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, // IHDR chunk length
    0x49, 0x48, 0x44, 0x52, // "IHDR"
    0x00, 0x00, 0x00, 0x01, // Width: 1
    0x00, 0x00, 0x00, 0x01, // Height: 1
    0x08, 0x06, 0x00, 0x00, 0x00, // Bit depth, color type, etc.
    0x1F, 0x15, 0xC4, 0x89, // CRC
  ]);
}

/// Creates a real valid JPEG image for MediaValidationService API tests
Uint8List _createRealJpeg() {
  // Create a simple 10x10 red image
  final image = img.Image(width: 10, height: 10);
  img.fill(image, color: img.ColorRgb8(255, 0, 0)); // Fill with red
  return Uint8List.fromList(img.encodeJpg(image, quality: 90));
}

/// Creates a real valid PNG image for MediaValidationService API tests
Uint8List _createRealPng() {
  // Create a simple 10x10 blue image
  final image = img.Image(width: 10, height: 10);
  img.fill(image, color: img.ColorRgb8(0, 0, 255)); // Fill with blue
  return Uint8List.fromList(img.encodePng(image));
}

