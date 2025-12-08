import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/services/blossom_client.dart';
import 'package:mostro_mobile/services/encryption_service.dart';
import 'package:mostro_mobile/services/blossom_download_service.dart';
import 'package:mostro_mobile/core/config/blossom_config.dart';

class EncryptedImageUploadResult {
  final String blossomUrl;
  final String nonce; // Hex encoded
  final String mimeType;
  final int originalSize;
  final int width;
  final int height;
  final String filename;
  final int encryptedSize;

  EncryptedImageUploadResult({
    required this.blossomUrl,
    required this.nonce,
    required this.mimeType,
    required this.originalSize,
    required this.width,
    required this.height,
    required this.filename,
    required this.encryptedSize,
  });

  /// Convert to JSON for NIP-59 rumor content
  Map<String, dynamic> toJson() {
    return {
      'type': 'image_encrypted',
      'blossom_url': blossomUrl,
      'nonce': nonce,
      'mime_type': mimeType,
      'original_size': originalSize,
      'width': width,
      'height': height,
      'filename': filename,
      'encrypted_size': encryptedSize,
    };
  }

  /// Create from JSON (for receiving messages)
  factory EncryptedImageUploadResult.fromJson(Map<String, dynamic> json) {
    return EncryptedImageUploadResult(
      blossomUrl: json['blossom_url'],
      nonce: json['nonce'],
      mimeType: json['mime_type'],
      originalSize: json['original_size'],
      width: json['width'],
      height: json['height'],
      filename: json['filename'],
      encryptedSize: json['encrypted_size'],
    );
  }
}

class EncryptedImageUploadService {
  final Logger _logger = Logger();
  
  
  EncryptedImageUploadService();

  /// Upload encrypted image with complete sanitization and encryption
  Future<EncryptedImageUploadResult> uploadEncryptedImage({
    required File imageFile,
    required Uint8List sharedKey,
    String? filename,
  }) async {
    _logger.i('🔒 Starting encrypted image upload process...');
    
    try {
      // 1. Read file
      final imageData = await imageFile.readAsBytes();
      _logger.d('Read image file: ${imageData.length} bytes');
      
      // 2. Validate and sanitize with light sanitization for better performance
      final validationResult = await MediaValidationService.validateAndSanitizeImageLight(
        imageData
      );
      
      _logger.i(
        'Image validated and sanitized: ${validationResult.mimeType}, '
        '${validationResult.width}x${validationResult.height}, '
        '${validationResult.validatedData.length} bytes (sanitized)'
      );
      
      // 3. Encrypt with ChaCha20-Poly1305
      final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
        key: sharedKey,
        plaintext: validationResult.validatedData,
      );
      
      final encryptedBlob = encryptionResult.toBlob();
      _logger.i(
        '🔐 Image encrypted successfully: ${encryptedBlob.length} bytes '
        '(nonce: ${encryptionResult.nonce.length}B, '
        'data: ${encryptionResult.encryptedData.length}B, '
        'tag: ${encryptionResult.authTag.length}B)'
      );
      
      // 4. Upload encrypted blob to Blossom
      final blossomUrl = await _uploadWithRetry(
        encryptedBlob,
        'application/octet-stream', // Always octet-stream for encrypted data
      );
      
      // 5. Generate filename if not provided
      final finalFilename = filename ?? 
        'image_${DateTime.now().millisecondsSinceEpoch}.${validationResult.extension}';
      
      final result = EncryptedImageUploadResult(
        blossomUrl: blossomUrl,
        nonce: _bytesToHex(encryptionResult.nonce),
        mimeType: validationResult.mimeType,
        originalSize: validationResult.validatedData.length,
        width: validationResult.width,
        height: validationResult.height,
        filename: finalFilename,
        encryptedSize: encryptedBlob.length,
      );
      
      _logger.i('🎉 Encrypted image upload completed successfully!');
      _logger.i('📸 Blossom URL: ${result.blossomUrl}');
      _logger.i('🔑 Nonce: ${result.nonce}');
      
      return result;
      
    } catch (e) {
      _logger.e('❌ Encrypted image upload failed: $e');
      rethrow;
    }
  }

  /// Download and decrypt image from Blossom
  Future<Uint8List> downloadAndDecryptImage({
    required String blossomUrl,
    required String nonceHex,
    required Uint8List sharedKey,
  }) async {
    _logger.i('🔓 Starting encrypted image download and decryption...');
    _logger.d('URL: $blossomUrl');
    _logger.d('Nonce: $nonceHex');
    
    try {
      // 1. Download encrypted blob from Blossom
      final encryptedBlob = await _downloadFromBlossom(blossomUrl);
      _logger.i('📥 Downloaded encrypted blob: ${encryptedBlob.length} bytes');
      
      // 2. Decrypt with ChaCha20-Poly1305
      final decryptedImage = EncryptionService.decryptFromBlob(
        key: sharedKey,
        blob: encryptedBlob,
      );
      
      _logger.i('🔓 Image decrypted successfully: ${decryptedImage.length} bytes');
      
      return decryptedImage;
      
    } catch (e) {
      _logger.e('❌ Image download/decryption failed: $e');
      rethrow;
    }
  }
  
  /// Upload with automatic retry to multiple servers
  Future<String> _uploadWithRetry(Uint8List encryptedData, String mimeType) async {
    final servers = BlossomConfig.defaultServers;
    
    for (int i = 0; i < servers.length; i++) {
      final serverUrl = servers[i];
      _logger.d('Attempting upload to server ${i + 1}/${servers.length}: $serverUrl');
      
      try {
        final client = BlossomClient(serverUrl: serverUrl);
        final blossomUrl = await client.uploadImage(
          imageData: encryptedData,
          mimeType: mimeType,
        );
        
        _logger.i('✅ Upload successful to: $serverUrl');
        return blossomUrl;
        
      } catch (e) {
        _logger.w('❌ Upload failed to $serverUrl: $e');
        
        // If it's the last server, re-throw the error
        if (i == servers.length - 1) {
          throw BlossomException('All Blossom servers failed. Last error: $e');
        }
        
        // Continue with next server
        continue;
      }
    }
    
    throw BlossomException('No Blossom servers available');
  }

  /// Download from Blossom with retry
  Future<Uint8List> _downloadFromBlossom(String blossomUrl) async {
    return await BlossomDownloadService.downloadWithRetry(blossomUrl);
  }
  
  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

