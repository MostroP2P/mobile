import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/encrypted_file_upload_service.dart';
import 'package:mostro_mobile/services/encrypted_image_upload_service.dart';
import 'package:mostro_mobile/services/file_validation_service.dart';
import 'package:mostro_mobile/services/media_validation_service.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

/// Shared file upload logic for both P2P chat and dispute chat.
/// Each caller provides its own getSharedKey and sendMessage callbacks.
class ChatFileUploadHelper {
  static final EncryptedFileUploadService _fileUploadService =
      EncryptedFileUploadService();
  static final EncryptedImageUploadService _imageUploadService =
      EncryptedImageUploadService();

  /// Select a file, encrypt it, upload to Blossom, and send the JSON metadata.
  /// Returns true if upload succeeded, false otherwise.
  static Future<bool> selectAndUploadFile({
    required BuildContext context,
    required Future<Uint8List> Function() getSharedKey,
    required Future<void> Function(String jsonMessage) sendMessage,
    required bool Function() isMounted,
  }) async {
    // Cache localized strings before async operations
    final l10n = S.of(context)!;
    final maxMb =
        (FileValidationService.maxFileSize ~/ (1024 * 1024)).toString();

    try {
      // Show native file picker
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: FileValidationService.getSupportedExtensions()
            .map((ext) => ext.substring(1))
            .toList(),
        allowMultiple: false,
      );

      if (!isMounted()) return false;

      if (result == null || result.files.single.path == null) {
        return false;
      }

      final file = File(result.files.single.path!);
      final filename = result.files.single.name;

      // Check file size before loading into memory to prevent OOM
      final fileSize = await file.length();
      if (fileSize > FileValidationService.maxFileSize) {
        if (!isMounted()) return false;
        final currentMb = (fileSize / (1024 * 1024)).toStringAsFixed(1);
        SnackBarHelper.showTopSnackBar(
          // ignore: use_build_context_synchronously
          context,
          l10n.fileTooLarge(currentMb, maxMb),
          backgroundColor: Colors.red,
        );
        return false;
      }

      // Show confirmation dialog before uploading
      // ignore: use_build_context_synchronously
      final shouldUpload = await _showFileConfirmationDialog(context, filename);
      if (!isMounted()) return false;
      if (!shouldUpload) return false;

      // Get shared key for encryption
      final sharedKey = await getSharedKey();

      // Determine if this is an image or other file type
      final mimeType = lookupMimeType(filename);
      final isImage =
          MediaValidationService.isImageTypeSupported(mimeType ?? '');

      if (isImage) {
        final uploadResult = await _imageUploadService.uploadEncryptedImage(
          imageFile: file,
          sharedKey: sharedKey,
          filename: filename,
        );
        await sendMessage(jsonEncode(uploadResult.toJson()));
      } else {
        final uploadResult = await _fileUploadService.uploadEncryptedFile(
          file: file,
          sharedKey: sharedKey,
        );
        await sendMessage(jsonEncode(uploadResult.toJson()));
      }

      return true;
    } catch (e) {
      if (isMounted()) {
        SnackBarHelper.showTopSnackBar(
          // ignore: use_build_context_synchronously
          context,
          l10n.errorUploadingFile(e.toString()),
          backgroundColor: Colors.red,
        );
      }
      return false;
    }
  }

  static Future<bool> _showFileConfirmationDialog(
      BuildContext context, String filename) async {
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
}
