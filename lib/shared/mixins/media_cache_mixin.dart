import 'package:flutter/foundation.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';

/// One cached blob, tracked globally so the budget is a real ceiling rather
/// than a per-conversation one. The owner is held weakly: the list is
/// process-global, and a strong reference would keep a notifier (and every
/// blob in its maps) alive if `dispose()` never ran.
class _MediaCacheEntry {
  _MediaCacheEntry(MediaCacheMixin owner, this.kind, this.messageId, this.bytes)
      : owner = WeakReference(owner);

  final WeakReference<MediaCacheMixin> owner;
  final _MediaKind kind;
  final String messageId;
  int bytes;
}

/// Images and files are separate maps, so one message id may hold both;
/// keying the accounting by kind keeps their bytes from overwriting each
/// other.
enum _MediaKind { image, file }

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
  void _mediaTouch(_MediaKind kind, String messageId, {int? bytes}) {
    final index = _lru.indexWhere(
      (e) =>
          identical(e.owner.target, this) &&
          e.kind == kind &&
          e.messageId == messageId,
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
        ? _MediaCacheEntry(this, kind, messageId, size)
        : (entry..bytes = size));
    _totalBytes += size;
    _evict();
  }

  /// Evicts from the least recently used end until the budget is met. The
  /// entry just touched (the last one) is never evicted: an entry larger than
  /// the whole budget would otherwise evict itself, and the widget that asked
  /// for it would re-download and re-decrypt it on every rebuild.
  static void _evict() {
    while (_totalBytes > mediaCacheMaxBytes && _lru.length > 1) {
      final oldest = _lru.removeAt(0);
      _totalBytes -= oldest.bytes;
      // Metadata is kept: it is small, and the widgets re-request the blob on
      // a miss, which re-decrypts and re-caches it. A collected owner has
      // already released its maps; only the accounting was left to drop.
      final owner = oldest.owner.target;
      if (owner == null) continue;
      switch (oldest.kind) {
        case _MediaKind.image:
          owner._imageCache.remove(oldest.messageId);
        case _MediaKind.file:
          owner._fileCache.remove(oldest.messageId);
      }
    }
  }

  void cacheDecryptedImage(
      String messageId, Uint8List data, EncryptedImageUploadResult meta) {
    _imageCache[messageId] = data;
    _imageMetadata[messageId] = meta;
    _mediaTouch(_MediaKind.image, messageId, bytes: data.length);
  }

  Uint8List? getCachedImage(String messageId) {
    final data = _imageCache[messageId];
    // Reads promote too, or the cache would evict a hot entry FIFO-style.
    if (data != null) _mediaTouch(_MediaKind.image, messageId);
    return data;
  }

  EncryptedImageUploadResult? getImageMetadata(String messageId) =>
      _imageMetadata[messageId];

  void cacheDecryptedFile(
      String messageId, Uint8List? data, EncryptedFileUploadResult meta) {
    if (data != null) {
      _fileCache[messageId] = data;
      _mediaTouch(_MediaKind.file, messageId, bytes: data.length);
    }
    _fileMetadata[messageId] = meta;
  }

  Uint8List? getCachedFile(String messageId) {
    final data = _fileCache[messageId];
    if (data != null) _mediaTouch(_MediaKind.file, messageId);
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
      if (!identical(e.owner.target, this)) return false;
      _totalBytes -= e.bytes;
      return true;
    });
  }
}
