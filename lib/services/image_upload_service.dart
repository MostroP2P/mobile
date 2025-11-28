import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/services/blossom_client.dart';

class ImageUploadService {
  final Logger _logger = Logger();
  
  // List of Blossom servers (with fallbacks)
  static const List<String> _blossomServers = [
    'https://blossom.primal.net',
    'https://blossom.band',
    'https://nostr.media',
    'https://blossom.sector01.com',
    'https://24242.io',
    'https://otherstuff.shaving.kiwi',
    'https://blossom.f7z.io',
    'https://nosto.re',
    'https://blossom.poster.place',
  ];
  
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
    final servers = _blossomServers; // Always use real Blossom servers
    
    for (int i = 0; i < servers.length; i++) {
      final serverUrl = servers[i];
      _logger.d('Attempting upload to server ${i + 1}/${servers.length}: $serverUrl');
      
      try {
        final client = BlossomClient(serverUrl: serverUrl);
        final blossomUrl = await client.uploadImage(
          imageData: imageData,
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
}