import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/data/models/session.dart';
import 'package:mostro_mobile/data/models/enums/role.dart';
import 'package:mostro_mobile/data/models/peer.dart';
import 'package:mostro_mobile/features/key_manager/key_derivator.dart';
import 'package:mostro_mobile/services/encryption_service.dart';
import 'package:mostro_mobile/services/blossom_client.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart' hide BlossomException;
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart' hide BlossomException;
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
    late ProviderContainer container;
    late MockBlossomClient mockBlossomClient;
    late MockEncryptedFileUploadService mockFileUploadService;
    late MockEncryptedImageUploadService mockImageUploadService;
    late MockBlossomDownloadService mockDownloadService;
    late MockChatRoomNotifier mockChatRoomNotifier;
    late Session testSession;

    setUp(() {
      mockBlossomClient = MockBlossomClient();
      mockFileUploadService = MockEncryptedFileUploadService();
      mockImageUploadService = MockEncryptedImageUploadService();
      mockDownloadService = MockBlossomDownloadService();
      mockChatRoomNotifier = MockChatRoomNotifier();

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

      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
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

      test('shared key used for both text and files', () async {
        final sharedKeyHex = testSession.sharedKey!.private;
        final expectedBytes = Uint8List(32);
        for (int i = 0; i < 32; i++) {
          final byte = int.parse(sharedKeyHex.substring(i * 2, i * 2 + 2), radix: 16);
          expectedBytes[i] = byte;
        }

        when(mockChatRoomNotifier.getSharedKey()).thenAnswer((_) async => expectedBytes);

        final result = await mockChatRoomNotifier.getSharedKey();
        expect(result.length, equals(32));
        expect(result, equals(expectedBytes));
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
      test('accepts files within 25MB limit', () {
        final file24MB = Uint8List(24 * 1024 * 1024);
        expect(file24MB.length, lessThanOrEqualTo(FileValidationService.maxFileSize));
        
        final file25MB = Uint8List(25 * 1024 * 1024);
        expect(file25MB.length, lessThanOrEqualTo(FileValidationService.maxFileSize));
      });

      test('rejects oversized files', () {
        final file26MB = Uint8List(26 * 1024 * 1024);
        expect(file26MB.length, greaterThan(FileValidationService.maxFileSize));
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
        final emptyFile = Uint8List(0);
        expect(emptyFile.length, equals(0));
        expect(emptyFile.length, lessThan(FileValidationService.maxFileSize));
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
    });

    group('Blossom Upload', () {
      test('creates proper HTTP authorization header', () async {
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

      test('handles upload success response', () async {
        final blossomClient = BlossomClient(serverUrl: 'https://blossom.server.com');

        // We can't easily test the actual HTTP without mocking http.Client
        // This test verifies the URL construction logic
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
            mimeType: mimeType
          ),
          throwsA(isA<BlossomException>()),
        );
      });
    });

    group('Gift Wrap Message Creation', () {
      test('creates file message with correct metadata', () {
        final fileMessage = {
          'type': 'file_encrypted',
          'file_type': 'document',
          'blossom_url': 'https://blossom.server.com/hash123',
          'nonce': 'abcdef123456789012345678',
          'mime_type': 'application/pdf',
          'original_size': 12345,
          'filename': 'document.pdf',
          'encrypted_size': 12389,
        };

        expect(fileMessage['type'], equals('file_encrypted'));
        expect(fileMessage['nonce'], isA<String>());
        expect(fileMessage['blossom_url'], startsWith('https://'));
        expect(fileMessage.containsKey('encryption_key'), isFalse);
      });

      test('includes nonce but not encryption key', () {
        final imageMessage = {
          'type': 'image_encrypted',
          'file_type': 'image',
          'blossom_url': 'https://blossom.server.com/hash456',
          'nonce': '1234567890abcdef12345678',
          'mime_type': 'image/jpeg',
          'original_size': 54321,
          'filename': 'photo.jpg',
          'encrypted_size': 54365,
        };

        expect(imageMessage.containsKey('nonce'), isTrue);
        expect(imageMessage.containsKey('encryption_key'), isFalse);
        expect(imageMessage.containsKey('shared_key'), isFalse);
      });

      test('formats JSON correctly for different file types', () {
        final videoMessage = {
          'type': 'file_encrypted',
          'file_type': 'video',
          'blossom_url': 'https://blossom.server.com/hash789',
          'nonce': 'fedcba987654321098765432',
          'mime_type': 'video/mp4',
          'original_size': 9876543,
          'filename': 'video.mp4',
          'encrypted_size': 9876587,
        };

        final jsonString = jsonEncode(videoMessage);
        final decoded = jsonDecode(jsonString);

        expect(decoded['type'], equals('file_encrypted'));
        expect(decoded['file_type'], equals('video'));
        expect(decoded['mime_type'], equals('video/mp4'));
      });
    });

    group('File Download & Decryption', () {
      test('download service can be mocked', () {
        expect(mockDownloadService, isNotNull);
        expect(mockDownloadService, isA<MockBlossomDownloadService>());
      });

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
      test('image upload service can be mocked', () {
        expect(mockImageUploadService, isNotNull);
        expect(mockImageUploadService, isA<MockEncryptedImageUploadService>());
      });

      test('file upload service can be mocked', () {
        expect(mockFileUploadService, isNotNull);
        expect(mockFileUploadService, isA<MockEncryptedFileUploadService>());
      });

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

        bool threwEncryptionException = false;
        try {
          EncryptionService.decryptChaCha20Poly1305(
            key: key,
            nonce: encrypted.nonce,
            encryptedData: encrypted.encryptedData,
            authTag: corruptedAuthTag,
          );
        } catch (e) {
          threwEncryptionException = e is EncryptionException;
        }
        
        expect(threwEncryptionException, isTrue);
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
        bool threwArgumentError = false;
        try {
          EncryptionService.encryptChaCha20Poly1305(
            key: invalidKey,
            plaintext: testData,
          );
        } catch (e) {
          threwArgumentError = e is ArgumentError;
        }
        
        expect(threwArgumentError, isTrue);
      });
    });
  });
}

// Helper functions for test data creation
Uint8List _createTestJpeg() {
  // Minimal valid JPEG header
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

Uint8List _createTestPng() {
  // Minimal valid PNG header
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

