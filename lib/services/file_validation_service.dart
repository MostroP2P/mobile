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
      'image/png'
    ],
    'video': [
      'video/mp4',
      'video/quicktime',
      'video/x-msvideo' // AVI
    ],
    'document': [
      'application/pdf',
      'application/msword', // DOC
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document' // DOCX
    ]
  };
  
  static const Map<String, String> extensionToMime = {
    // Images
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.png': 'image/png',
    
    // Videos
    '.mp4': 'video/mp4',
    '.mov': 'video/quicktime',
    '.avi': 'video/x-msvideo',
    
    // Documents
    '.pdf': 'application/pdf',
    '.doc': 'application/msword',
    '.docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
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
    
    // 5. Perform type-specific validation
    await _performTypeSpecificValidation(fileData, mimeType, fileType);
    
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
  
  /// Perform type-specific validation based on file type
  static Future<void> _performTypeSpecificValidation(
    Uint8List fileData, 
    String mimeType, 
    String fileType
  ) async {
    switch (fileType) {
      case 'document':
        if (mimeType == 'application/pdf') {
          await _validatePdfStructure(fileData);
        } else if (mimeType == 'application/msword' || 
                   mimeType == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
          await _validateDocumentStructure(fileData, mimeType);
        }
        break;
      case 'video':
        await _validateVideoStructure(fileData, mimeType);
        break;
      // Images are handled by MediaValidationService
      case 'image':
        break;
    }
  }
  
  /// Validate PDF structure and security
  static Future<void> _validatePdfStructure(Uint8List fileData) async {
    _logger.d('🔍 Validating PDF structure...');
    
    // Check PDF header
    if (fileData.length < 8) {
      throw FileValidationException('PDF file too small or corrupted');
    }
    
    // PDF files must start with %PDF-
    final header = String.fromCharCodes(fileData.take(5));
    if (!header.startsWith('%PDF-')) {
      throw FileValidationException('Invalid PDF header');
    }
    
    // Check for PDF trailer (should end with %%EOF or whitespace)
    final tail = String.fromCharCodes(fileData.skip(fileData.length - 20).take(20));
    if (!tail.contains('%%EOF')) {
      _logger.w('⚠️ PDF may be incomplete (no %%EOF trailer found)');
    }
    
    _logger.d('✅ PDF structure validation passed');
  }
  
  /// Validate DOC/DOCX structure and check for macros
  static Future<void> _validateDocumentStructure(Uint8List fileData, String mimeType) async {
    _logger.d('🔍 Validating document structure...');
    
    if (mimeType == 'application/msword') {
      // DOC file validation - check OLE header
      if (fileData.length < 8) {
        throw FileValidationException('DOC file too small or corrupted');
      }
      
      // DOC files start with OLE signature: D0CF11E0A1B11AE1
      final oleHeader = fileData.take(8).toList();
      final expectedHeader = [0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1];
      
      bool headerMatches = true;
      for (int i = 0; i < 8; i++) {
        if (oleHeader[i] != expectedHeader[i]) {
          headerMatches = false;
          break;
        }
      }
      
      if (!headerMatches) {
        throw FileValidationException('Invalid DOC file format');
      }
      
      // Basic macro detection for DOC files
      final fileString = String.fromCharCodes(fileData);
      if (fileString.contains('VBA') || fileString.contains('Microsoft Visual Basic')) {
        throw FileValidationException('Document contains macros which are not allowed for security reasons');
      }
    } 
    else if (mimeType == 'application/vnd.openxmlformats-officedocument.wordprocessingml.document') {
      // DOCX file validation - check ZIP header
      if (fileData.length < 4) {
        throw FileValidationException('DOCX file too small or corrupted');
      }
      
      // DOCX files are ZIP archives, should start with PK header
      if (fileData[0] != 0x50 || fileData[1] != 0x4B) {
        throw FileValidationException('Invalid DOCX file format (not a ZIP archive)');
      }
      
      // Basic macro detection - look for vbaProject.bin in the ZIP structure
      final fileString = String.fromCharCodes(fileData);
      if (fileString.contains('vbaProject.bin') || fileString.contains('macros/')) {
        throw FileValidationException('Document contains macros which are not allowed for security reasons');
      }
    }
    
    _logger.d('✅ Document structure validation passed');
  }
  
  /// Validate video file structure
  static Future<void> _validateVideoStructure(Uint8List fileData, String mimeType) async {
    _logger.d('🔍 Validating video structure...');
    
    if (fileData.length < 12) {
      throw FileValidationException('Video file too small or corrupted');
    }
    
    switch (mimeType) {
      case 'video/mp4':
        // MP4 files should have 'ftyp' box near the beginning
        final header = String.fromCharCodes(fileData.skip(4).take(4));
        if (header != 'ftyp') {
          throw FileValidationException('Invalid MP4 file structure');
        }
        break;
      case 'video/quicktime':
        // MOV files also use 'ftyp' box or 'moov' box
        final header1 = String.fromCharCodes(fileData.skip(4).take(4));
        final header2 = String.fromCharCodes(fileData.skip(8).take(4));
        if (header1 != 'ftyp' && header1 != 'moov' && header2 != 'moov') {
          throw FileValidationException('Invalid MOV file structure');
        }
        break;
      case 'video/x-msvideo':
        // AVI files start with RIFF header followed by AVI 
        final riff = String.fromCharCodes(fileData.take(4));
        final avi = String.fromCharCodes(fileData.skip(8).take(3));
        if (riff != 'RIFF' || avi != 'AVI') {
          throw FileValidationException('Invalid AVI file structure');
        }
        break;
    }
    
    _logger.d('✅ Video structure validation passed');
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