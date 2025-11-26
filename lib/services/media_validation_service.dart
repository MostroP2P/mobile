import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:mime/mime.dart';

enum SupportedImageType {
  jpeg,
  png,
  gif,
  webp,
}

extension SupportedImageTypeExtension on SupportedImageType {
  String get mimeType {
    switch (this) {
      case SupportedImageType.jpeg:
        return 'image/jpeg';
      case SupportedImageType.png:
        return 'image/png';
      case SupportedImageType.gif:
        return 'image/gif';
      case SupportedImageType.webp:
        return 'image/webp';
    }
  }

  String get extension {
    switch (this) {
      case SupportedImageType.jpeg:
        return 'jpg';
      case SupportedImageType.png:
        return 'png';
      case SupportedImageType.gif:
        return 'gif';
      case SupportedImageType.webp:
        return 'webp';
    }
  }

  static const List<SupportedImageType> all = [
    SupportedImageType.jpeg,
    SupportedImageType.png,
    SupportedImageType.gif,
    SupportedImageType.webp,
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
  /// Sanitizes and validates image exactly like whitenoise
  /// 1. Detects format from data (not extension)
  /// 2. Validates that it's a complete and valid image
  /// 3. Re-encodes to eliminate malicious metadata
  static Future<MediaValidationResult> validateAndSanitizeImage(
    Uint8List imageData,
  ) async {
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
      case 'image/gif':
        detectedType = SupportedImageType.gif;
        break;
      case 'image/webp':
        detectedType = SupportedImageType.webp;
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
        case SupportedImageType.gif:
          sanitizedData = Uint8List.fromList(img.encodeGif(decodedImage));
          break;
        case SupportedImageType.webp:
          // Convert WebP to PNG (WebP encoding not available in this image package version)
          sanitizedData = Uint8List.fromList(img.encodePng(decodedImage));
          detectedType = SupportedImageType.png;
          break;
      }
    } catch (e) {
      throw MediaValidationException('Failed to re-encode image: $e');
    }

    return MediaValidationResult(
      imageType: detectedType,
      mimeType: detectedType.mimeType,
      extension: detectedType.extension,
      validatedData: sanitizedData,
      width: decodedImage.width,
      height: decodedImage.height,
    );
  }
}

class MediaValidationException implements Exception {
  final String message;
  MediaValidationException(this.message);
  
  @override
  String toString() => 'MediaValidationException: $message';
}