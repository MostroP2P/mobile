import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config/blossom_config.dart';
import 'package:mostro_mobile/services/blossom_client.dart';

/// Shared utility for uploading data to Blossom servers with automatic retry
class BlossomUploadHelper {
  static final Logger _logger = Logger();
  
  /// Upload data to Blossom servers with automatic retry across multiple servers
  /// 
  /// Tries each server in [BlossomConfig.defaultServers] sequentially until one succeeds.
  /// If all servers fail, throws [BlossomException] with the last error.
  /// 
  /// Parameters:
  /// - [data]: The binary data to upload (can be raw image or encrypted blob)
  /// - [mimeType]: The MIME type of the data (e.g. 'image/jpeg', 'application/octet-stream')
  /// 
  /// Returns:
  /// - [String]: The Blossom URL where the data was successfully uploaded
  /// 
  /// Throws:
  /// - [BlossomException]: When all servers fail to upload the data
  static Future<String> uploadWithRetry(
    Uint8List data,
    String mimeType,
  ) async {
    final servers = BlossomConfig.defaultServers;
    
    for (int i = 0; i < servers.length; i++) {
      final serverUrl = servers[i];
      _logger.d('Attempting upload to server ${i + 1}/${servers.length}: $serverUrl');
      
      try {
        final client = BlossomClient(serverUrl: serverUrl);
        final blossomUrl = await client.uploadImage(
          imageData: data,
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