import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

class BlossomClient {
  final String serverUrl;
  final Duration timeout;
  final Logger _logger = Logger();
  
  BlossomClient({
    required this.serverUrl,
    this.timeout = const Duration(minutes: 5),
  });

  /// Upload sanitized image to Blossom
  Future<String> uploadImage({
    required Uint8List imageData,
    required String mimeType,
  }) async {
    // 1. Calculate SHA-256 hash of data
    final hash = sha256.convert(imageData);
    final hashHex = hash.toString();
    
    _logger.d('Uploading image to Blossom: ${imageData.length} bytes, hash: $hashHex');
    
    // 2. Generate unique keys for authentication
    final authKeys = NostrUtils.generateKeyPair();
    
    // 3. Create Nostr authentication event (kind 24242 for Blossom)
    final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final authEvent = NostrEvent.fromPartialData(
      kind: 24242,
      content: 'Upload image',
      keyPairs: authKeys,
      tags: [
        ['t', 'upload'],
        ['x', hashHex],
        ['expiration', (timestamp + 3600).toString()], // Valid for 1 hour
      ],
      createdAt: DateTime.fromMillisecondsSinceEpoch(timestamp * 1000),
    );
    
    // 4. Encode authorization
    final authBase64 = base64.encode(
      utf8.encode(jsonEncode(authEvent.toMap()))
    );
    
    // 5. HTTP PUT request to Blossom upload endpoint
    final url = Uri.parse('$serverUrl/upload');
    
    _logger.d('PUT $url');
    
    try {
      final response = await http.put(
        url,
        headers: {
          'Content-Type': mimeType,
          'Authorization': 'Nostr $authBase64',
          'User-Agent': 'MostroMobile/1.0',
        },
        body: imageData,
      ).timeout(timeout);
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        // Blossom returns the file URL in the response, construct from hash
        final blossomUrl = '$serverUrl/$hashHex';
        _logger.i('✅ Image uploaded successfully to Blossom: $blossomUrl');
        return blossomUrl;
      } else {
        _logger.e('❌ Blossom upload failed: ${response.statusCode} - ${response.body}');
        throw BlossomException(
          'Upload failed: ${response.statusCode} - ${response.body}'
        );
      }
    } catch (e) {
      _logger.e('❌ Blossom upload error: $e');
      rethrow;
    }
  }
}

class BlossomException implements Exception {
  final String message;
  BlossomException(this.message);
  
  @override
  String toString() => 'BlossomException: $message';
}