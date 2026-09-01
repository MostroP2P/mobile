import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';

/// One cached blob, tracked globally so the budget is a real ceiling rather
/// than a per-conversation one.
class _MediaCacheEntry {
  _MediaCacheEntry(this.owner, this.messageId, this.bytes);

  final MediaCacheMixin owner;
  final String messageId;
  int bytes;
}

/// Shared media cache for decrypted images and files.
/// Used by both ChatRoomNotifier (P2P) and DisputeChatNotifier.
mixin MediaCacheMixin {
  /// Combined byte budget for decrypted media, shared by every conversation:
  /// these notifiers live for the whole app run, so an unbounded cache held
  /// every decrypted photo and file forever, and a per-notifier budget would
  /// multiply the ceiling by the number of conversations. The least recently
  /// used entries are evicted once the budget is hit (they re-decrypt on
  /// demand from the stored blob).
  static const int mediaCacheMaxBytes = 32 * 1024 * 1024;

  static final List<_MediaCacheEntry> _lru = [];
  static int _totalBytes = 0;

  @visibleForTesting
  static int get debugMediaCacheBytes => _totalBytes;

  @visibleForTesting
  static void debugResetMediaCache() {
    _lru.clear();
    _totalBytes = 0;
  }

  final Map<String, Uint8List> _imageCache = {};
  final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, EncryptedFileUploadResult> _fileMetadata = {};

  /// Moves an entry to the most-recently-used end. [bytes] is the new size on
  /// a write; omitted on a read, which promotes without changing accounting.
  void _mediaTouch(String messageId, {int? bytes}) {
    final index = _lru.indexWhere(
      (e) => identical(e.owner, this) && e.messageId == messageId,
    );
    _MediaCacheEntry? entry;
    if (index >= 0) {
      entry = _lru.removeAt(index);
      _totalBytes -= entry.bytes;
    }
    final size = bytes ?? entry?.bytes;
    // A read miss has nothing to promote.
    if (size == null) return;
    _lru.add(entry == null
        ? _MediaCacheEntry(this, messageId, size)
        : (entry..bytes = size));
    _totalBytes += size;
    _evict();
  }

  static void _evict() {
    while (_totalBytes > mediaCacheMaxBytes && _lru.isNotEmpty) {
      final oldest = _lru.removeAt(0);
      _totalBytes -= oldest.bytes;
      // Metadata is kept: it is small, and the widgets re-request the blob on
      // a miss, which re-decrypts and re-caches it.
      oldest.owner._imageCache.remove(oldest.messageId);
      oldest.owner._fileCache.remove(oldest.messageId);
    }
  }

  void cacheDecryptedImage(
      String messageId, Uint8List data, EncryptedImageUploadResult meta) {
    _imageCache[messageId] = data;
    _imageMetadata[messageId] = meta;
    _mediaTouch(messageId, bytes: data.length);
  }

  Uint8List? getCachedImage(String messageId) {
    final data = _imageCache[messageId];
    // Reads promote too, or the cache would evict a hot entry FIFO-style.
    if (data != null) _mediaTouch(messageId);
    return data;
  }

  EncryptedImageUploadResult? getImageMetadata(String messageId) =>
      _imageMetadata[messageId];

  void cacheDecryptedFile(
      String messageId, Uint8List? data, EncryptedFileUploadResult meta) {
    if (data != null) {
      _fileCache[messageId] = data;
      _mediaTouch(messageId, bytes: data.length);
    }
    _fileMetadata[messageId] = meta;
  }

  Uint8List? getCachedFile(String messageId) {
    final data = _fileCache[messageId];
    if (data != null) _mediaTouch(messageId);
    return data;
  }

  EncryptedFileUploadResult? getFileMetadata(String messageId) =>
      _fileMetadata[messageId];

  void clearMediaCaches() {
    _imageCache.clear();
    _imageMetadata.clear();
    _fileCache.clear();
    _fileMetadata.clear();
    _lru.removeWhere((e) {
      if (!identical(e.owner, this)) return false;
      _totalBytes -= e.bytes;
      return true;
    });
  }
}
