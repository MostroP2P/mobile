import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';

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
  Widget build(BuildContext context) {
    final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
    
    // Check if image is already cached
    final cachedImage = chatNotifier.getCachedImage(widget.message.id!);
    final imageMetadata = chatNotifier.getImageMetadata(widget.message.id!);

    if (cachedImage != null && imageMetadata != null) {
      return _buildImageWidget(cachedImage, imageMetadata);
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    // Try to load the image
    _loadImage();
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
              'Decrypting image...',
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
              'Failed to load image',
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

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
      
      // Parse the message content to get image data
      final content = widget.message.content;
      if (content == null || !content.startsWith('{')) {
        throw Exception('Invalid image message format');
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
        nonceHex: imageData.nonce,
        sharedKey: sharedKey,
      );

      // Cache the image
      chatNotifier.cacheDecryptedImage(widget.message.id!, decryptedImage, imageData);

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
}

/// Helper function to check if a message is an encrypted image
bool isEncryptedImageMessage(NostrEvent message) {
  try {
    final content = message.content;
    if (content == null || !content.startsWith('{')) return false;
    
    // ignore: avoid_dynamic_calls
    final jsonContent = jsonDecode(content) as Map<String, dynamic>;
    return jsonContent['type'] == 'image_encrypted';
  } catch (e) {
    return false;
  }
}