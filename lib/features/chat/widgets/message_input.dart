import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/chat/providers/chat_room_providers.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';

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
  final ImagePicker _imagePicker = ImagePicker();
  final EncryptedImageUploadService _imageUploadService = EncryptedImageUploadService();
  
  bool _isUploadingImage = false; // For loading indicator

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

  // Handle image selection, encryption and upload
  Future<void> _selectAndUploadImage() async {
    try {
      setState(() {
        _isUploadingImage = true;
      });

      // Show image picker modal
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85, // Compress for faster upload
      );

      if (pickedFile != null) {
        // Get shared key for this order/chat
        final sharedKey = await _getSharedKeyForOrder(widget.orderId);
        
        // Upload encrypted image to Blossom
        final result = await _imageUploadService.uploadEncryptedImage(
          imageFile: File(pickedFile.path),
          sharedKey: sharedKey,
          filename: pickedFile.name,
        );
        
        // Send encrypted image message via NIP-59
        await _sendEncryptedImageMessage(result);
      }
    } catch (e) {
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
      }
    }
  }

  // Get shared key for this order/chat session
  Future<Uint8List> _getSharedKeyForOrder(String orderId) async {
    // Get the chat room notifier to access the shared key
    final chatNotifier = ref.read(chatRoomsProvider(orderId).notifier);
    return await chatNotifier.getSharedKey();
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
                    icon: _isUploadingImage
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: AppTheme.cream1,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.add,
                            color: AppTheme.cream1,
                            size: 20,
                          ),
                    onPressed: _isUploadingImage ? null : _selectAndUploadImage,
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