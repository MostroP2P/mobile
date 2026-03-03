import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class DisputeMessageInput extends ConsumerStatefulWidget {
  final String disputeId;

  const DisputeMessageInput({
    super.key,
    required this.disputeId,
  });

  @override
  ConsumerState<DisputeMessageInput> createState() =>
      _DisputeMessageInputState();
}

class _DisputeMessageInputState extends ConsumerState<DisputeMessageInput> {
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final EncryptedFileUploadService _fileUploadService =
      EncryptedFileUploadService();
  final EncryptedImageUploadService _imageUploadService =
      EncryptedImageUploadService();

  bool _isUploadingFile = false;

  @override
  void dispose() {
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isNotEmpty) {
      ref
          .read(disputeChatNotifierProvider(widget.disputeId).notifier)
          .sendMessage(text);
      _textController.clear();
      _focusNode.requestFocus();
    }
  }

  Future<void> _selectAndUploadFile() async {
    try {
      setState(() {
        _isUploadingFile = true;
      });

      // Show native file picker
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: FileValidationService.getSupportedExtensions()
            .map((ext) => ext.substring(1))
            .toList(),
        allowMultiple: false,
      );

      if (!mounted) return;

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final filename = result.files.single.name;

        // Show confirmation dialog before uploading
        final shouldUpload = await _showFileConfirmationDialog(filename);
        if (!mounted) return;
        if (!shouldUpload) {
          return;
        }

        // Get admin shared key for encryption
        final sharedKey = await ref
            .read(disputeChatNotifierProvider(widget.disputeId).notifier)
            .getAdminSharedKey();

        // Determine if this is an image or other file type
        final fileData = await file.readAsBytes();
        final isImage = await _isImageFile(fileData, filename);

        if (isImage) {
          final uploadResult = await _imageUploadService.uploadEncryptedImage(
            imageFile: file,
            sharedKey: sharedKey,
            filename: filename,
          );

          await _sendEncryptedMessage(uploadResult.toJson());
        } else {
          final uploadResult = await _fileUploadService.uploadEncryptedFile(
            file: file,
            sharedKey: sharedKey,
          );

          await _sendEncryptedMessage(uploadResult.toJson());
        }
      }
    } catch (e) {
      if (mounted) {
        SnackBarHelper.showTopSnackBar(
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

  Future<void> _sendEncryptedMessage(Map<String, dynamic> resultJson) async {
    final messageJson = jsonEncode(resultJson);
    await ref
        .read(disputeChatNotifierProvider(widget.disputeId).notifier)
        .sendMessage(messageJson);
  }

  Future<bool> _isImageFile(Uint8List fileData, String filename) async {
    try {
      final mimeType = await _getMimeType(fileData, filename);
      return MediaValidationService.isImageTypeSupported(mimeType ?? '');
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getMimeType(Uint8List fileData, String filename) async {
    final mimeFromBytes = lookupMimeType('', headerBytes: fileData);
    if (mimeFromBytes != null) {
      return mimeFromBytes;
    }
    return lookupMimeType(filename);
  }

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

    return result ?? false;
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              // Attach file button
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.textSecondary.withValues(alpha: 0.3),
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
              // Text input field
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
                          color:
                              AppTheme.textSecondary.withValues(alpha: 0.6),
                          fontSize: 15),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
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
              // Send button
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
      ),
    );
  }
}
