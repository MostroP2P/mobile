import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';

class BlossomDownloadService {
  static final Logger _logger = Logger();
  static const Duration _timeout = Duration(minutes: 2);

  /// Download encrypted blob from Blossom server
  static Future<Uint8List> downloadFromBlossom(String blossomUrl) async {
    _logger.i('📥 Starting download from Blossom: $blossomUrl');
    
    try {
      final uri = Uri.parse(blossomUrl);
      _logger.d('GET $uri');

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'MostroMobile/1.0',
          'Accept': 'application/octet-stream, */*',
        },
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = response.bodyBytes;
        _logger.i('✅ Download successful: ${data.length} bytes');
        return data;
      } else {
        _logger.e('❌ Download failed: ${response.statusCode} - ${response.body}');
        throw BlossomDownloadException(
          'Download failed: HTTP ${response.statusCode} - ${response.body}'
        );
      }
    } catch (e) {
      _logger.e('❌ Download error: $e');
      if (e is BlossomDownloadException) {
        rethrow;
      }
      throw BlossomDownloadException('Network error: $e');
    }
  }

  /// Download with retry mechanism for better reliability
  static Future<Uint8List> downloadWithRetry(
    String blossomUrl, {
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 1),
  }) async {
    _logger.i('📥 Download with retry: $blossomUrl (max $maxRetries attempts)');

    Exception? lastException;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        _logger.d('Attempt $attempt/$maxRetries');
        return await downloadFromBlossom(blossomUrl);
      } catch (e) {
        lastException = e is Exception ? e : Exception(e.toString());
        _logger.w('❌ Attempt $attempt failed: $e');
        
        if (attempt < maxRetries) {
          _logger.d('⏳ Waiting ${retryDelay.inMilliseconds}ms before retry...');
          await Future.delayed(retryDelay);
          // Exponential backoff
          retryDelay = Duration(milliseconds: (retryDelay.inMilliseconds * 1.5).round());
        }
      }
    }

    _logger.e('❌ All download attempts failed');
    throw BlossomDownloadException('All $maxRetries download attempts failed. Last error: $lastException');
  }

  /// Check if a Blossom URL is valid and accessible (HEAD request)
  static Future<bool> isBlossomUrlAccessible(String blossomUrl) async {
    try {
      final uri = Uri.parse(blossomUrl);
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10)
      );
      return response.statusCode == 200;
    } catch (e) {
      _logger.w('🔍 URL accessibility check failed for $blossomUrl: $e');
      return false;
    }
  }

  /// Get content length without downloading the full file
  static Future<int?> getContentLength(String blossomUrl) async {
    try {
      final uri = Uri.parse(blossomUrl);
      final response = await http.head(uri).timeout(
        const Duration(seconds: 10)
      );
      
      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          return int.tryParse(contentLength);
        }
      }
      return null;
    } catch (e) {
      _logger.w('🔍 Content length check failed for $blossomUrl: $e');
      return null;
    }
  }

  /// Download with progress callback for UI updates
  static Future<Uint8List> downloadWithProgress(
    String blossomUrl,
    void Function(int downloaded, int total)? onProgress,
  ) async {
    _logger.i('📥 Download with progress tracking: $blossomUrl');

    try {
      final uri = Uri.parse(blossomUrl);
      final request = http.Request('GET', uri);
      request.headers['User-Agent'] = 'MostroMobile/1.0';
      request.headers['Accept'] = 'application/octet-stream, */*';

      final client = http.Client();
      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        throw BlossomDownloadException(
          'Download failed: HTTP ${response.statusCode}'
        );
      }

      final contentLength = response.contentLength ?? 0;
      final bytes = <int>[];
      int downloaded = 0;

      await for (final chunk in response.stream) {
        bytes.addAll(chunk);
        downloaded += chunk.length;
        
        if (onProgress != null && contentLength > 0) {
          onProgress(downloaded, contentLength);
        }
      }

      client.close();

      final data = Uint8List.fromList(bytes);
      _logger.i('✅ Download with progress completed: ${data.length} bytes');
      return data;
      
    } catch (e) {
      _logger.e('❌ Download with progress failed: $e');
      if (e is BlossomDownloadException) {
        rethrow;
      }
      throw BlossomDownloadException('Network error: $e');
    }
  }
}

class BlossomDownloadException implements Exception {
  final String message;
  BlossomDownloadException(this.message);

  @override
  String toString() => 'BlossomDownloadException: $message';
}