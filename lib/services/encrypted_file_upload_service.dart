import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/blossom_upload_helper.dart';
import 'package:mostro_mobile/services/encryption_service.dart';
import 'package:mostro_mobile/services/blossom_download_service.dart';

class EncryptedFileUploadResult {
  final String blossomUrl;
  final String nonce; // Hex encoded
  final String mimeType;
  final String fileType;
  final int originalSize;
  final String filename;
  final int encryptedSize;

  EncryptedFileUploadResult({
    required this.blossomUrl,
    required this.nonce,
    required this.mimeType,
    required this.fileType,
    required this.originalSize,
    required this.filename,
    required this.encryptedSize,
  });

  /// Convert to JSON for NIP-59 rumor content
  Map<String, dynamic> toJson() {
    return {
      'type': 'file_encrypted',
      'file_type': fileType,
      'blossom_url': blossomUrl,
      'nonce': nonce,
      'mime_type': mimeType,
      'original_size': originalSize,
      'filename': filename,
      'encrypted_size': encryptedSize,
    };
  }

  /// Create from JSON (for receiving messages)
  factory EncryptedFileUploadResult.fromJson(Map<String, dynamic> json) {
    try {
      return EncryptedFileUploadResult(
        blossomUrl: json['blossom_url'] as String,
        nonce: json['nonce'] as String,
        mimeType: json['mime_type'] as String,
        fileType: json['file_type'] as String,
        originalSize: json['original_size'] as int,
        filename: json['filename'] as String,
        encryptedSize: json['encrypted_size'] as int,
      );
    } catch (e) {
      throw FormatException('Invalid EncryptedFileUploadResult JSON: $e');
    }
  }
}

class EncryptedFileUploadService {
  final Logger _logger = Logger();
  
  
  EncryptedFileUploadService();

  /// Upload encrypted file with complete validation and encryption
  Future<EncryptedFileUploadResult> uploadEncryptedFile({
    required File file,
    required Uint8List sharedKey,
  }) async {
    _logger.i('🔒 Starting encrypted file upload process...');
    
    try {
      // 1. Validate file (size, type, security)
      final validationResult = await FileValidationService.validateFile(file);
      
      _logger.i(
        'File validated: ${validationResult.fileType} (${validationResult.mimeType}), '
        '${validationResult.filename}, ${_formatFileSize(validationResult.size)}'
      );
      
      // 2. Encrypt with ChaCha20-Poly1305
      final encryptionResult = EncryptionService.encryptChaCha20Poly1305(
        key: sharedKey,
        plaintext: validationResult.validatedData,
      );
      
      final encryptedBlob = encryptionResult.toBlob();
      _logger.i(
        '🔐 File encrypted successfully: ${encryptedBlob.length} bytes '
        '(nonce: ${encryptionResult.nonce.length}B, '
        'data: ${encryptionResult.encryptedData.length}B, '
        'tag: ${encryptionResult.authTag.length}B)'
      );
      
      // 3. Upload encrypted blob to Blossom
      final blossomUrl = await _uploadWithRetry(
        encryptedBlob,
        'application/octet-stream', // Always octet-stream for encrypted data
      );
      
      final result = EncryptedFileUploadResult(
        blossomUrl: blossomUrl,
        nonce: _bytesToHex(encryptionResult.nonce),
        mimeType: validationResult.mimeType,
        fileType: validationResult.fileType,
        originalSize: validationResult.size,
        filename: validationResult.filename,
        encryptedSize: encryptedBlob.length,
      );
      
      _logger.i('🎉 Encrypted file upload completed successfully!');
      _logger.i('📎 File: ${result.filename} (${result.fileType})');
      _logger.i('🔗 Blossom URL: ${result.blossomUrl}');
      
      return result;
      
    } catch (e) {
      _logger.e('❌ Encrypted file upload failed: $e');
      rethrow;
    }
  }

  /// Download and decrypt file from Blossom
  /// The nonce is automatically extracted from the encrypted blob
  Future<Uint8List> downloadAndDecryptFile({
    required String blossomUrl,
    required Uint8List sharedKey,
  }) async {
    _logger.i('🔓 Starting encrypted file download and decryption...');
    _logger.d('URL: $blossomUrl');
    
    try {
      // 1. Download encrypted blob from Blossom
      final encryptedBlob = await _downloadFromBlossom(blossomUrl);
      _logger.i('📥 Downloaded encrypted blob: ${encryptedBlob.length} bytes');
      
      // 2. Decrypt with ChaCha20-Poly1305
      final decryptedFile = EncryptionService.decryptFromBlob(
        key: sharedKey,
        blob: encryptedBlob,
      );
      
      _logger.i('🔓 File decrypted successfully: ${decryptedFile.length} bytes');
      
      return decryptedFile;
      
    } catch (e) {
      _logger.e('❌ File download/decryption failed: $e');
      rethrow;
    }
  }
  
  /// Upload with automatic retry to multiple servers
  Future<String> _uploadWithRetry(Uint8List encryptedData, String mimeType) async {
    return BlossomUploadHelper.uploadWithRetry(encryptedData, mimeType);
  }

  /// Download from Blossom with retry
  Future<Uint8List> _downloadFromBlossom(String blossomUrl) async {
    return await BlossomDownloadService.downloadWithRetry(blossomUrl);
  }
  
  /// Convert bytes to hex string
  String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
  
  /// Format file size in human-readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
}

