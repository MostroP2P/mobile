import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/services/blossom_upload_helper.dart';

class ImageUploadService {
  final Logger _logger = Logger();
  
  
  ImageUploadService();

  /// Upload image with complete sanitization
  Future<String> uploadImage(File imageFile) async {
    _logger.i('Starting image upload process...');
    
    try {
      // 1. Read file
      final imageData = await imageFile.readAsBytes();
      _logger.d('Read image file: ${imageData.length} bytes');
      
      // 2. Validate and sanitize (like whitenoise)
      final validationResult = await MediaValidationService.validateAndSanitizeImage(
        imageData
      );
      
      _logger.i(
        'Image validated and sanitized: ${validationResult.mimeType}, '
        '${validationResult.width}x${validationResult.height}, '
        '${validationResult.validatedData.length} bytes (sanitized)'
      );
      
      // 3. Upload to Blossom with sanitized data
      final blossomUrl = await _uploadWithRetry(
        validationResult.validatedData,
        validationResult.mimeType,
      );
      
      _logger.i('🎉 Image upload completed successfully!');
      _logger.i('📸 Blossom URL: $blossomUrl');
      
      return blossomUrl;
      
    } catch (e) {
      _logger.e('❌ Image upload failed: $e');
      rethrow;
    }
  }
  
  /// Upload with automatic retry to multiple servers
  Future<String> _uploadWithRetry(Uint8List imageData, String mimeType) async {
    return BlossomUploadHelper.uploadWithRetry(imageData, mimeType);
  }
}