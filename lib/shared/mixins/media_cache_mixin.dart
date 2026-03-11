import 'dart:typed_data';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';

/// Shared media cache for decrypted images and files.
/// Used by both ChatRoomNotifier (P2P) and DisputeChatNotifier.
mixin MediaCacheMixin {
  final Map<String, Uint8List> _imageCache = {};
  final Map<String, EncryptedImageUploadResult> _imageMetadata = {};
  final Map<String, Uint8List> _fileCache = {};
  final Map<String, EncryptedFileUploadResult> _fileMetadata = {};

  void cacheDecryptedImage(
      String messageId, Uint8List data, EncryptedImageUploadResult meta) {
    _imageCache[messageId] = data;
    _imageMetadata[messageId] = meta;
  }

  Uint8List? getCachedImage(String messageId) => _imageCache[messageId];

  EncryptedImageUploadResult? getImageMetadata(String messageId) =>
      _imageMetadata[messageId];

  void cacheDecryptedFile(
      String messageId, Uint8List? data, EncryptedFileUploadResult meta) {
    if (data != null) {
      _fileCache[messageId] = data;
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
  }
}
