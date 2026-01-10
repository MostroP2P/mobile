import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mostro_mobile/common/top_snackbar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';

class MessageInput extends ConsumerStatefulWidget {
  final String orderId;
  final String? selectedInfoType;
  final ValueChanged<String?> onInfoTypeChanged;

  const MessageInput({
    super.key,
    required this.orderId,
    required this.selectedInfoType,
    required this.onInfoTypeChanged,
  });

  @override
  ConsumerState<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends ConsumerState<MessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final EncryptedFileUploadService _fileUploadService = EncryptedFileUploadService();
  final EncryptedImageUploadService _imageUploadService = EncryptedImageUploadService();
  
  bool _isUploadingFile = false; // For loading indicator

  @override
  void initState() {
    super.initState();
    // Add listener to focus node to detect keyboard visibility changes
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }
  
  // Handle focus changes to detect keyboard visibility
  void _onFocusChange() {
    if (_focusNode.hasFocus && widget.selectedInfoType != null) {
      // Close info panels when keyboard opens
      widget.onInfoTypeChanged(null);
    }
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(chatRoomsProvider(widget.orderId).notifier)
          .sendMessage(text);
      _textController.clear();
    }
  }

  // Handle file selection, encryption and upload
  Future<void> _selectAndUploadFile() async {
    try {
      setState(() {
        _isUploadingFile = true;
      });

      // Show native file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: FileValidationService.getSupportedExtensions()
            .map((ext) => ext.substring(1)) // Remove the dot from extensions
            .toList(),
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final filename = result.files.single.name;
        
        // Show confirmation dialog before uploading
        final shouldUpload = await _showFileConfirmationDialog(filename);
        if (!shouldUpload) {
          return; // User cancelled, exit without uploading
        }
        
        // Get shared key for this order/chat
        final sharedKey = await _getSharedKeyForOrder(widget.orderId);
        
        // Determine if this is an image or other file type
        final fileData = await file.readAsBytes();
        final isImage = await _isImageFile(fileData, filename);
        
        if (isImage) {
          // Handle as image with light sanitization
          final uploadResult = await _imageUploadService.uploadEncryptedImage(
            imageFile: file,
            sharedKey: sharedKey,
            filename: filename,
          );
          
          // Send encrypted image message via NIP-59
          await _sendEncryptedImageMessage(uploadResult);
        } else {
          // Handle as document/video with validation
          final uploadResult = await _fileUploadService.uploadEncryptedFile(
            file: file,
            sharedKey: sharedKey,
          );
          
          // Send encrypted file message via NIP-59
          await _sendEncryptedFileMessage(uploadResult);
        }
      }
    } catch (e) {
      // Show error to user
      if (mounted) {
        showTopSnackBar(
          context,
          S.of(context)!.errorUploadingFile(e.toString()),
           backgroundColor: Colors.red,
     );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingFile = false;
        });
      }
    }
  }

  // Determine if a file is an image based on content and extension
  Future<bool> _isImageFile(Uint8List fileData, String filename) async {
    try {
      // Use mime detection to check if it's an image
      final mimeType = await _getMimeType(fileData, filename);
      return MediaValidationService.isImageTypeSupported(mimeType ?? '');
    } catch (e) {
      return false;
    }
  }
  
  // Get MIME type for a file
  Future<String?> _getMimeType(Uint8List fileData, String filename) async {
    // First try magic bytes detection
    final mimeFromBytes = lookupMimeType('', headerBytes: fileData);
    if (mimeFromBytes != null) {
      return mimeFromBytes;
    }
    
    // Fallback to extension-based detection
    return lookupMimeType(filename);
  }

  // Get shared key for this order/chat session
  Future<Uint8List> _getSharedKeyForOrder(String orderId) async {
    // Get the chat room notifier to access the shared key
    final chatNotifier = ref.read(chatRoomsProvider(orderId).notifier);
    return await chatNotifier.getSharedKey();
  }

  // Send encrypted file message via NIP-59 gift wrap
  Future<void> _sendEncryptedFileMessage(EncryptedFileUploadResult result) async {
    try {
      // Create JSON content for the rumor
      final fileMessageJson = jsonEncode(result.toJson());
      
      // Send via existing chat system (will be wrapped in NIP-59)
      await ref
          .read(chatRoomsProvider(widget.orderId).notifier)
          .sendMessage(fileMessageJson);
          
    } catch (e) {
      throw Exception('Failed to send encrypted file message: $e');
    }
  }

  // Send encrypted image message via NIP-59 gift wrap
  Future<void> _sendEncryptedImageMessage(EncryptedImageUploadResult result) async {
    try {
      // Create JSON content for the rumor
      final imageMessageJson = jsonEncode(result.toJson());
      
      // Send via existing chat system (will be wrapped in NIP-59)
      await ref
          .read(chatRoomsProvider(widget.orderId).notifier)
          .sendMessage(imageMessageJson);
          
    } catch (e) {
      throw Exception('Failed to send encrypted image message: $e');
    }
  }

  // Show confirmation dialog for file upload
  Future<bool> _showFileConfirmationDialog(String filename) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          title: Text(
            S.of(context)!.confirmFileUpload,
            style: TextStyle(
              color: AppTheme.cream1,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                S.of(context)!.sendThisFile,
                style: TextStyle(
                  color: AppTheme.cream1,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundInput,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  filename,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                S.of(context)!.cancel,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.mostroGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                S.of(context)!.send,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    return result ?? false; // If dialog is dismissed, treat as cancelled
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundDark,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 12 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              children: [
                // + Button for image upload
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundDark,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppTheme.textSecondary.withValues(alpha: 76), // 0.3 opacity
                      width: 1,
                    ),
                  ),
                  child: IconButton(
                    icon: _isUploadingFile
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.cream1,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.attach_file,
                            color: AppTheme.cream1,
                            size: 20,
                          ),
                    onPressed: _isUploadingFile ? null : _selectAndUploadFile,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: AppTheme.backgroundInput,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      enabled: true,
                      style: TextStyle(
                        color: AppTheme.cream1,
                        fontSize: 15,
                      ),
                      decoration: InputDecoration(
                        hintText: S.of(context)!.typeAMessage,
                        hintStyle: TextStyle(
                            color: AppTheme.textSecondary.withValues(alpha: 153), // 0.6 opacity
                            fontSize: 15),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        isDense: true,
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.mostroGreen,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: _sendMessage,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}