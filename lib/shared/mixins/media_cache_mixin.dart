import 'dart:typed_data';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';

/// Shared media cache for decrypted images and files.
/// Used by both ChatRoomNotifier (P2P) and DisputeChatNotifier.
mixin MediaCacheMixin {
  /// Combined byte budget for decrypted media. These notifiers live for the
  /// whole app run, so an unbounded cache held every decrypted photo and
  /// file forever; the oldest entries are evicted once the budget is hit
  /// (they re-decrypt on demand from the stored blob).
  static const int mediaCacheMaxBytes = 32 * 1024 * 1024;

  final Map<String, Uint8List> _imageCache = {};
  final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, EncryptedFileUploadResult> _fileMetadata = {};
  final List<String> _mediaLru = [];
  int _mediaBytes = 0;

  int get debugMediaCacheBytes => _mediaBytes;

  void _mediaTouch(String messageId, int addedBytes) {
    _mediaLru.remove(messageId);
    _mediaLru.add(messageId);
    _mediaBytes += addedBytes;
    while (_mediaBytes > mediaCacheMaxBytes && _mediaLru.isNotEmpty) {
      final oldest = _mediaLru.removeAt(0);
      _mediaBytes -= _imageCache.remove(oldest)?.length ?? 0;
      _mediaBytes -= _fileCache.remove(oldest)?.length ?? 0;
    }
  }

  void cacheDecryptedImage(
      String messageId, Uint8List data, EncryptedImageUploadResult meta) {
    final previous = _imageCache[messageId]?.length ?? 0;
    _imageCache[messageId] = data;
    _imageMetadata[messageId] = meta;
    _mediaTouch(messageId, data.length - previous);
  }

  Uint8List? getCachedImage(String messageId) => _imageCache[messageId];

  EncryptedImageUploadResult? getImageMetadata(String messageId) =>
      _imageMetadata[messageId];

  void cacheDecryptedFile(
      String messageId, Uint8List? data, EncryptedFileUploadResult meta) {
    if (data != null) {
      final previous = _fileCache[messageId]?.length ?? 0;
      _fileCache[messageId] = data;
      _mediaTouch(messageId, data.length - previous);
    }
    _fileMetadata[messageId] = meta;
  }

  Uint8List? getCachedFile(String messageId) => _fileCache[messageId];

  EncryptedFileUploadResult? getFileMetadata(String messageId) =>
      _fileMetadata[messageId];

  void clearMediaCaches() {
    _imageCache.clear();
    _imageMetadata.clear();
    _fileCache.clear();
    _fileMetadata.clear();
    _mediaLru.clear();
    _mediaBytes = 0;
  }
}
