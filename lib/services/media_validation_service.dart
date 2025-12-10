import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';
import 'package:logger/logger.dart';

enum SupportedImageType {
  jpeg,
  png,
}

extension SupportedImageTypeExtension on SupportedImageType {
  String get mimeType {
    switch (this) {
      case SupportedImageType.jpeg:
        return 'image/jpeg';
      case SupportedImageType.png:
        return 'image/png';
    }
  }

  String get extension {
    switch (this) {
      case SupportedImageType.jpeg:
        return 'jpg';
      case SupportedImageType.png:
        return 'png';
    }
  }

  static const List<SupportedImageType> all = [
    SupportedImageType.jpeg,
    SupportedImageType.png,
  ];
}

class MediaValidationResult {
  final SupportedImageType imageType;
  final String mimeType;
  final String extension;
  final Uint8List validatedData;
  final int width;
  final int height;

  MediaValidationResult({
    required this.imageType,
    required this.mimeType,
    required this.extension,
    required this.validatedData,
    required this.width,
    required this.height,
  });
}

class MediaValidationService {
  static final Logger _logger = Logger();
  
  /// Sanitizes and validates image exactly like whitenoise
  /// 1. Detects format from data (not extension)
  /// 2. Validates that it's a complete and valid image
  /// 3. Re-encodes to eliminate malicious metadata
  static Future<MediaValidationResult> validateAndSanitizeImage(
    Uint8List imageData,
  ) async {
    return _sanitizeImageHeavy(imageData);
  }
  
  /// Light image sanitization for better performance
  /// 1. Detects format using magic bytes
  /// 2. Basic integrity check via decode
  /// 3. Strips metadata only (no heavy pixel validation)
  /// 4. Quick re-encode with minimal quality loss
  static Future<MediaValidationResult> validateAndSanitizeImageLight(
    Uint8List imageData,
  ) async {
    _logger.i('📸 Light image sanitization started: ${imageData.length} bytes');
    
    if (imageData.isEmpty) {
      throw MediaValidationException('File is empty');
    }

    // STEP 1: Detect format using magic bytes
    SupportedImageType? detectedType;
    
    // Use mime package for initial detection
    final mimeType = lookupMimeType('', headerBytes: imageData);
    
    switch (mimeType) {
      case 'image/jpeg':
        detectedType = SupportedImageType.jpeg;
        break;
      case 'image/png':
        detectedType = SupportedImageType.png;
        break;
      default:
        throw MediaValidationException(
          'Unsupported image format: $mimeType. Supported formats: ${SupportedImageTypeExtension.all.map((t) => t.mimeType).join(", ")}'
        );
    }

    // STEP 2: Basic integrity check via decode (no pixel validation)
    img.Image? decodedImage;
    try {
      decodedImage = img.decodeImage(imageData);
      if (decodedImage == null) {
        throw MediaValidationException(
          'Invalid or corrupted ${detectedType.mimeType} image: Could not decode'
        );
      }
    } on MediaValidationException {
      rethrow;
    } catch (e) {
      throw MediaValidationException(
        'Invalid or corrupted ${detectedType.mimeType} image: $e'
      );
    }

    // STEP 3: Quick re-encode to strip metadata with minimal quality loss
    Uint8List sanitizedData;
    try {
      switch (detectedType) {
        case SupportedImageType.jpeg:
          // Use quality 95 to minimize quality loss while stripping EXIF
          sanitizedData = Uint8List.fromList(img.encodeJpg(decodedImage, quality: 95));
          break;
        case SupportedImageType.png:
          // PNG is lossless, so no quality concerns
          sanitizedData = Uint8List.fromList(img.encodePng(decodedImage));
          break;
      }
    } catch (e) {
      throw MediaValidationException('Failed to re-encode image: $e');
    }

    _logger.i('✅ Light image sanitization completed: ${sanitizedData.length} bytes');
    
    return MediaValidationResult(
      imageType: detectedType,
      mimeType: detectedType.mimeType,
      extension: detectedType.extension,
      validatedData: sanitizedData,
      width: decodedImage.width,
      height: decodedImage.height,
    );
  }
  
  /// Heavy image sanitization (original method) for maximum security
  static Future<MediaValidationResult> _sanitizeImageHeavy(
    Uint8List imageData,
  ) async {
    _logger.i('🔒 Heavy image sanitization started: ${imageData.length} bytes');
    
    if (imageData.isEmpty) {
      throw MediaValidationException('File is empty');
    }

    // STEP 1: Detect format using magic bytes (like whitenoise)
    SupportedImageType? detectedType;
    
    // Use mime package for initial detection
    final mimeType = lookupMimeType('', headerBytes: imageData);
    
    switch (mimeType) {
      case 'image/jpeg':
        detectedType = SupportedImageType.jpeg;
        break;
      case 'image/png':
        detectedType = SupportedImageType.png;
        break;
      default:
        throw MediaValidationException(
          'Unsupported image format: $mimeType. Supported formats: ${SupportedImageTypeExtension.all.map((t) => t.mimeType).join(", ")}'
        );
    }

    // STEP 2: Validate using image package (like whitenoise)
    // This ensures the image is valid and complete
    img.Image? decodedImage;
    try {
      decodedImage = img.decodeImage(imageData);
      if (decodedImage == null) {
        throw MediaValidationException(
          'Invalid or corrupted ${detectedType.mimeType} image: Could not decode'
        );
      }
    } on MediaValidationException {
      rethrow;
    } catch (e) {
      throw MediaValidationException(
        'Invalid or corrupted ${detectedType.mimeType} image: $e'
      );
    }

    // STEP 3: Re-encode to sanitize (removes EXIF and other metadata)
    Uint8List sanitizedData;
    try {
      switch (detectedType) {
        case SupportedImageType.jpeg:
          sanitizedData = Uint8List.fromList(img.encodeJpg(decodedImage, quality: 90));
          break;
        case SupportedImageType.png:
          sanitizedData = Uint8List.fromList(img.encodePng(decodedImage));
          break;
      }
    } catch (e) {
      throw MediaValidationException('Failed to re-encode image: $e');
    }

    _logger.i('✅ Heavy image sanitization completed: ${sanitizedData.length} bytes');

    return MediaValidationResult(
      imageType: detectedType,
      mimeType: detectedType.mimeType,
      extension: detectedType.extension,
      validatedData: sanitizedData,
      width: decodedImage.width,
      height: decodedImage.height,
    );
  }
  
  /// Check if image type is supported in the new format restrictions
  static bool isImageTypeSupported(String mimeType) {
    return mimeType == 'image/jpeg' || mimeType == 'image/png';
  }
}

class MediaValidationException implements Exception {
  final String message;
  MediaValidationException(this.message);
  
  @override
  String toString() => 'MediaValidationException: $message';
}