import 'dart:io';
import 'dart:typed_data';
import 'package:mime/mime.dart';
import 'package:logger/logger.dart';

class FileValidationResult {
  final Uint8List validatedData;
  final String mimeType;
  final String fileType;
  final String extension;
  final int size;
  final String filename;

  FileValidationResult({
    required this.validatedData,
    required this.mimeType,
    required this.fileType,
    required this.extension,
    required this.size,
    required this.filename,
  });
}

class FileValidationService {
  static final Logger _logger = Logger();
  
  // Maximum file size: 25MB
  static const int maxFileSize = 25 * 1024 * 1024;
  
  // Supported file types for P2P proof of payment exchange
  static const Map<String, List<String>> supportedTypes = {
    'image': [
      'image/jpeg',
      'image/jpg', 
      'image/png',
      'image/gif',
      'image/webp'
    ],
    'video': [
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo', // AVI
      'video/webm'
    ],
    'document': [
      'application/pdf',
      'application/msword', // DOC
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document', // DOCX
      'text/plain',
      'text/rtf'
    ]
  };
  
  static const Map<String, String> extensionToMime = {
    // Images
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    '.gif': 'image/gif',
    '.webp': 'image/webp',
    
    // Videos
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    '.webm': 'video/webm',
    
    // Documents
    '.pdf': 'application/pdf',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    '.txt': 'text/plain',
    '.rtf': 'text/rtf'
  };

  /// Validate file for secure P2P exchange
  static Future<FileValidationResult> validateFile(File file) async {
    final filename = file.path.split('/').last;
    final fileData = await file.readAsBytes();
    
    _logger.i('🔍 Validating file: $filename (${fileData.length} bytes)');
    
    // 1. Check file size
    if (fileData.length > maxFileSize) {
      throw FileValidationException(
        'File too large: ${_formatFileSize(fileData.length)}. '
        'Maximum allowed: ${_formatFileSize(maxFileSize)}'
      );
    }
    
    // 2. Detect MIME type
    String? mimeType = lookupMimeType(file.path, headerBytes: fileData);
    
    // 3. Fallback to extension-based detection
    if (mimeType == null) {
      final extension = _getFileExtension(filename).toLowerCase();
      mimeType = extensionToMime[extension];
    }
    
    if (mimeType == null) {
      throw FileValidationException('Unsupported file type: $filename');
    }
    
    // 4. Verify MIME type is supported
    final fileType = _getFileType(mimeType);
    if (fileType == null) {
      throw FileValidationException('Unsupported file type: $mimeType');
    }
    
    _logger.i('✅ File validation successful: $fileType ($mimeType)');
    
    return FileValidationResult(
      validatedData: fileData,
      mimeType: mimeType,
      fileType: fileType,
      extension: _getFileExtension(filename),
      size: fileData.length,
      filename: filename,
    );
  }
  
  /// Get file type category from MIME type
  static String? _getFileType(String mimeType) {
    for (final entry in supportedTypes.entries) {
      if (entry.value.contains(mimeType)) {
        return entry.key;
      }
    }
    return null;
  }
  
  /// Get file extension from filename
  static String _getFileExtension(String filename) {
    final lastDot = filename.lastIndexOf('.');
    if (lastDot == -1) return '';
    return filename.substring(lastDot);
  }
  
  /// Format file size in human-readable format
  static String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }
  
  /// Check if file type is supported
  static bool isFileTypeSupported(String filename, {String? mimeType}) {
    // Check by MIME type first
    if (mimeType != null) {
      return _getFileType(mimeType) != null;
    }
    
    // Check by extension
    final extension = _getFileExtension(filename).toLowerCase();
    return extensionToMime.containsKey(extension);
  }
  
  /// Get supported file extensions for file picker
  static List<String> getSupportedExtensions() {
    return extensionToMime.keys.toList();
  }
  
  /// Get file type icon
  static String getFileTypeIcon(String fileType) {
    switch (fileType) {
      case 'image':
        return '🖼️';
      case 'video':
        return '🎥';
      case 'document':
        return '📄';
      default:
        return '📎';
    }
  }
}

class FileValidationException implements Exception {
  final String message;
  FileValidationException(this.message);
  
  @override
  String toString() => 'FileValidationException: $message';
}