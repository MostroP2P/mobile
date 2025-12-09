import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class EncryptedImageMessage extends ConsumerStatefulWidget {
  final NostrEvent message;
  final String orderId;
  final bool isOwnMessage;

  const EncryptedImageMessage({
    super.key,
    required this.message,
    required this.orderId,
    required this.isOwnMessage,
  });

  @override
  ConsumerState<EncryptedImageMessage> createState() => _EncryptedImageMessageState();
}

class _EncryptedImageMessageState extends ConsumerState<EncryptedImageMessage> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadImageIfNeeded();
    });
  }

  void _loadImageIfNeeded() {
    if (!mounted) return;
    
    final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
    final messageId = widget.message.id;
    if (messageId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = S.of(context)!.invalidMessageMissingId;
        });
      }
      return;
    }
    
    final cachedImage = chatNotifier.getCachedImage(messageId);
    if (cachedImage == null && !_isLoading) {
      _loadImage();
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
    
    // Handle null message ID defensively
    final messageId = widget.message.id;
    if (messageId == null) {
      return _buildErrorWidget();
    }
    
    // Check if image is already cached
    final cachedImage = chatNotifier.getCachedImage(messageId);
    final imageMetadata = chatNotifier.getImageMetadata(messageId);

    if (cachedImage != null && imageMetadata != null) {
      return _buildImageWidget(cachedImage, imageMetadata);
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    // Show loading widget while waiting for initState to trigger the load
    return _buildLoadingWidget();
  }

  Widget _buildImageWidget(Uint8List imageData, EncryptedImageUploadResult metadata) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate available space for the image (leave space for info row)
        const infoRowHeight = 20.0; // Height for the filename/size row
        const spacing = 4.0;
        const padding = 8.0; // Total vertical padding
        final availableHeight = constraints.maxHeight - infoRowHeight - spacing - padding;
        
        return Container(
          constraints: BoxConstraints(
            maxWidth: constraints.maxWidth.clamp(0, 280),
            maxHeight: constraints.maxHeight.clamp(0, 400),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Image container
              Flexible(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: availableHeight.clamp(100, 350), // Ensure reasonable min/max
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: GestureDetector(
                      onTap: () => _openImage(imageData, metadata),
                      child: Image.memory(
                        imageData,
                        fit: BoxFit.contain, // Use contain to prevent overflow
                        errorBuilder: (context, error, stackTrace) {
                          return _buildErrorWidget();
                        },
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: spacing),
              // Image info
              Container(
                height: infoRowHeight,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Icon(
                      Icons.image,
                      size: 12,
                      color: AppTheme.textSecondary.withValues(alpha: 153),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        metadata.filename,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.textSecondary.withValues(alpha: 153),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      _formatFileSize(metadata.originalSize),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary.withValues(alpha: 153),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        maxHeight: 150,
        minWidth: 200,
        minHeight: 120,
      ),
      decoration: BoxDecoration(
        color: AppTheme.backgroundInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.textSecondary.withValues(alpha: 76),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppTheme.mostroGreen,
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              S.of(context)!.decryptingImage,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary.withValues(alpha: 153),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        maxHeight: 120,
        minWidth: 200,
        minHeight: 80,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.red.withValues(alpha: 127),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 24,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              S.of(context)!.failedToLoadImage,
              style: TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _errorMessage!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.red.withValues(alpha: 153),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _loadImage() async {
    if (_isLoading) return;
    
    final messageId = widget.message.id;
    if (messageId == null) {
      if (mounted) {
        setState(() {
          _errorMessage = S.of(context)!.invalidMessageMissingId;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
      
      // Parse the message content to get image data
      final content = widget.message.content;
      if (content == null || !content.startsWith('{')) {
        throw Exception(S.of(context)!.invalidImageMessageFormat);
      }

      final imageData = EncryptedImageUploadResult.fromJson(
        Map<String, dynamic>.from(
          // ignore: avoid_dynamic_calls
          jsonDecode(content) as Map
        )
      );

      // Get shared key
      final sharedKey = await chatNotifier.getSharedKey();

      // Download and decrypt image
      final uploadService = EncryptedImageUploadService();
      final decryptedImage = await uploadService.downloadAndDecryptImage(
        blossomUrl: imageData.blossomUrl,
        sharedKey: sharedKey,
      );

      // Cache the image
      chatNotifier.cacheDecryptedImage(messageId, decryptedImage, imageData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  Future<void> _openImage(Uint8List imageData, EncryptedImageUploadResult metadata) async {
    // Cache localized strings before async operations
    final securityErrorMsg = S.of(context)!.securityErrorInvalidChars;
    final couldNotOpenMsg = S.of(context)!.couldNotOpenFile;
    final errorOpeningMsg = S.of(context)!.errorOpeningFile;
    
    try {
      
      // Save image to temporary directory
      final tempDir = await getTemporaryDirectory();
      final sanitizedFilename = _sanitizeFilename(metadata.filename);
      final tempFile = File('${tempDir.path}/$sanitizedFilename');
      
      // Security check
      if (sanitizedFilename.contains('/') || sanitizedFilename.contains('\\') || 
          sanitizedFilename.contains('..') || sanitizedFilename.trim().isEmpty) {
        throw Exception(securityErrorMsg);
      }
      
      await tempFile.writeAsBytes(imageData);

      // Open image with system default app
      final result = await OpenFile.open(tempFile.path);
      
      if (mounted) {
        if (result.type != ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$couldNotOpenMsg: ${result.message}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$errorOpeningMsg: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sanitize filename to prevent path traversal and other security issues
  String _sanitizeFilename(String filename) {
    // Get basename only (remove any directory components)
    final basename = filename.split(RegExp(r'[/\\]')).last;
    
    // Normalize accented characters
    String normalized = basename
        .replaceAll('á', 'a').replaceAll('é', 'e').replaceAll('í', 'i')
        .replaceAll('ó', 'o').replaceAll('ú', 'u').replaceAll('ñ', 'n')
        .replaceAll('ü', 'u').replaceAll('Á', 'A').replaceAll('É', 'E')
        .replaceAll('Í', 'I').replaceAll('Ó', 'O').replaceAll('Ú', 'U')
        .replaceAll('Ñ', 'N').replaceAll('Ü', 'U');
    
    // Replace spaces and remove dangerous characters
    final cleaned = normalized
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_')
        .replaceAll('..', '_');
    
    // Preserve file extension
    String sanitized = cleaned;
    if (sanitized.contains('.')) {
      final parts = sanitized.split('.');
      if (parts.length > 1) {
        final extension = parts.last;
        final nameWithoutExt = parts.sublist(0, parts.length - 1).join('_');
        final maxNameLength = 100 - extension.length - 1;
        final truncatedName = nameWithoutExt.length > maxNameLength 
            ? nameWithoutExt.substring(0, maxNameLength)
            : nameWithoutExt;
        sanitized = '$truncatedName.$extension';
      }
    } else {
      sanitized = sanitized.length > 100 ? sanitized.substring(0, 100) : sanitized;
    }
    
    // Ensure not empty and not Windows reserved names
    final nameOnly = sanitized.contains('.') ? sanitized.split('.').first : sanitized;
    if (sanitized.isEmpty || nameOnly.isEmpty ||
        ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 
         'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 
         'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'].contains(nameOnly.toUpperCase())) {
      final extension = sanitized.contains('.') ? '.${sanitized.split('.').last}' : '';
      return 'image_${DateTime.now().millisecondsSinceEpoch}$extension';
    }
    
    return sanitized;
  }
}