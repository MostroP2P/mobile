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
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class EncryptedFileMessage extends ConsumerStatefulWidget {
  final NostrEvent message;
  final String orderId;
  final bool isOwnMessage;

  const EncryptedFileMessage({
    super.key,
    required this.message,
    required this.orderId,
    required this.isOwnMessage,
  });

  @override
  ConsumerState<EncryptedFileMessage> createState() => _EncryptedFileMessageState();
}

class _EncryptedFileMessageState extends ConsumerState<EncryptedFileMessage> {
  bool _isLoading = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
    
    // Check if file is already cached
    final cachedFile = chatNotifier.getCachedFile(widget.message.id!);
    final fileMetadata = chatNotifier.getFileMetadata(widget.message.id!);

    if (cachedFile != null && fileMetadata != null) {
      // Check if it's an image and show preview
      if (_isImage(fileMetadata.fileType)) {
        return _buildImagePreview(cachedFile, fileMetadata);
      } else {
        return _buildFileWidget(cachedFile, fileMetadata);
      }
    }

    if (_isLoading) {
      return _buildLoadingWidget();
    }

    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    // Try to load the file metadata (for display without downloading)
    final metadata = _parseFileMetadata();
    if (metadata != null) {
      // For images, try to download automatically for preview
      if (_isImage(metadata.fileType)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_isLoading) {
            _downloadFile();
          }
        });
      }
      return _buildFileWidget(null, metadata);
    }

    return _buildErrorWidget();
  }

  bool _isImage(String fileType) {
    return fileType == 'image';
  }

  Widget _buildImagePreview(Uint8List imageData, EncryptedFileUploadResult metadata) {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        maxHeight: 300,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Image preview
            Image.memory(
              imageData,
              fit: BoxFit.cover,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 200,
                  color: Colors.grey.withValues(alpha: 51),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.broken_image,
                        color: AppTheme.textSecondary,
                        size: 48,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Failed to load image',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            // Image overlay info
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 178),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            metadata.filename,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            _formatFileSize(metadata.originalSize),
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 178),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => _openFile(),
                      icon: Icon(
                        Icons.open_in_new,
                        color: Colors.white.withValues(alpha: 178),
                        size: 16,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileWidget(Uint8List? fileData, EncryptedFileUploadResult metadata) {
    final icon = _getFileIcon(metadata.fileType);
    final isDownloaded = fileData != null;
    
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 200,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.backgroundCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppTheme.textSecondary.withValues(alpha: 76),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // File info row
            Row(
              children: [
                Text(
                  icon,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.filename,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatFileSize(metadata.originalSize),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 178),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.lock,
                            size: 12,
                            color: Colors.white.withValues(alpha: 178),
                          ),
                          Text(
                            ' ${S.of(context)!.encrypted}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withValues(alpha: 178),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Download/Open button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isDownloaded ? _openFile : _downloadFile,
                icon: Icon(
                  isDownloaded ? Icons.open_in_new : Icons.download,
                  size: 16,
                ),
                label: Text(
                  isDownloaded ? S.of(context)!.openFile : S.of(context)!.download,
                  style: const TextStyle(fontSize: 13),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.mostroGreen,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 200,
        maxHeight: 120,
        minHeight: 80,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
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
          Text(
            S.of(context)!.downloadingFile,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 178),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      constraints: const BoxConstraints(
        maxWidth: 280,
        minWidth: 200,
        maxHeight: 120,
        minHeight: 80,
      ),
      padding: const EdgeInsets.all(16),
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
          Text(
            'Failed to load file',
            style: TextStyle(
              fontSize: 12,
              color: Colors.red,
            ),
            textAlign: TextAlign.center,
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
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

  EncryptedFileUploadResult? _parseFileMetadata() {
    try {
      final content = widget.message.content;
      if (content == null || !content.startsWith('{')) {
        return null;
      }

      final fileData = EncryptedFileUploadResult.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(content) as Map
        )
      );

      return fileData;
    } catch (e) {
      return null;
    }
  }

  Future<void> _downloadFile() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
      final metadata = _parseFileMetadata();
      
      if (metadata == null) {
        throw Exception('Invalid file message format');
      }

      // Get shared key
      final sharedKey = await chatNotifier.getSharedKey();

      // Download and decrypt file
      final uploadService = EncryptedFileUploadService();
      final decryptedFile = await uploadService.downloadAndDecryptFile(
        blossomUrl: metadata.blossomUrl,
        nonceHex: metadata.nonce,
        sharedKey: sharedKey,
      );

      // Cache the file
      chatNotifier.cacheDecryptedFile(widget.message.id!, decryptedFile, metadata);

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

  Future<void> _openFile() async {
    try {
      final chatNotifier = ref.read(chatRoomsProvider(widget.orderId).notifier);
      final cachedFile = chatNotifier.getCachedFile(widget.message.id!);
      final metadata = chatNotifier.getFileMetadata(widget.message.id!);
      
      if (cachedFile == null || metadata == null) {
        throw Exception('File not available');
      }

      // Save file to temporary directory with sanitized filename
      final tempDir = await getTemporaryDirectory();
      final sanitizedFilename = _sanitizeFilename(metadata.filename);
      final tempFile = File('${tempDir.path}/$sanitizedFilename');
      
      // Verify the resolved path is still within the temp directory to prevent path traversal
      final tempDirPath = tempDir.resolveSymbolicLinksSync();
      final tempFilePath = tempFile.absolute.path;
      if (!tempFilePath.startsWith('$tempDirPath${Platform.pathSeparator}')) {
        throw Exception('Security error: Path traversal attempt detected in filename');
      }
      
      await tempFile.writeAsBytes(cachedFile);

      // Open file with system default app
      final result = await OpenFile.open(tempFile.path);
      
      if (mounted) {
        if (result.type == ResultType.done) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Opening ${metadata.filename}'),
              backgroundColor: AppTheme.mostroGreen,
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
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
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getFileIcon(String fileType) {
    return FileValidationService.getFileTypeIcon(fileType);
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  /// Sanitize filename to prevent path traversal and other security issues
  String _sanitizeFilename(String filename) {
    // 1. Get basename only (remove any directory components)
    final basename = filename.split(RegExp(r'[/\\]')).last;
    
    // 2. Remove dangerous characters including null bytes, control chars, and reserved chars
    final cleaned = basename.replaceAll(RegExp(r'[<>:"|?*\x00-\x1F]'), '_');
    
    // 3. Limit length to reasonable size
    final limited = cleaned.length > 100 ? cleaned.substring(0, 100) : cleaned;
    
    // 4. Ensure not empty and not Windows reserved names
    if (limited.isEmpty || 
        ['CON', 'PRN', 'AUX', 'NUL', 'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 
         'COM6', 'COM7', 'COM8', 'COM9', 'LPT1', 'LPT2', 'LPT3', 'LPT4', 
         'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9'].contains(limited.toUpperCase())) {
      return 'file_${DateTime.now().millisecondsSinceEpoch}';
    }
    
    return limited;
  }
}

/// Helper function to check if a message is an encrypted file
bool isEncryptedFileMessage(NostrEvent message) {
  try {
    final content = message.content;
    if (content == null || !content.startsWith('{')) return false;
    
    final jsonContent = jsonDecode(content) as Map<String, dynamic>;
    return jsonContent['type'] == 'file_encrypted';
  } catch (e) {
    return false;
  }
}