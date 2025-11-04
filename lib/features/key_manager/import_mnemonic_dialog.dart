import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class ImportMnemonicDialog extends StatefulWidget {
  const ImportMnemonicDialog({super.key});

  @override
  State<ImportMnemonicDialog> createState() => _ImportMnemonicDialogState();
}

class _ImportMnemonicDialogState extends State<ImportMnemonicDialog> {
  final TextEditingController _mnemonicController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _mnemonicController.dispose();
    super.dispose();
  }

  bool _validateMnemonic(String mnemonic) {
    final trimmed = mnemonic.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _errorMessage = null;
      });
      return false;
    }

    final words = trimmed.split(RegExp(r'\s+'));

    if (words.length != 12) {
      setState(() {
        _errorMessage = S.of(context)!.errorNotTwelveWords;
      });
      return false;
    }

    for (final word in words) {
      if (word.length < 3) {
        setState(() {
          _errorMessage = S.of(context)!.errorWordTooShort;
        });
        return false;
      }

      if (!RegExp(r'^[a-zA-Z]+$').hasMatch(word)) {
        setState(() {
          _errorMessage = S.of(context)!.errorInvalidCharacters;
        });
        return false;
      }
    }

    setState(() {
      _errorMessage = null;
    });
    return true;
  }

  void _handleImport() {
    final mnemonic = _mnemonicController.text.trim();

    if (_validateMnemonic(mnemonic)) {
      if (mounted) {
        Navigator.of(context).pop(mnemonic);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.backgroundCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.importMostroUserDialogTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              _buildInfoPoint(S.of(context)!.importMostroUserInfo1),
              const SizedBox(height: 12),
              _buildInfoPoint(S.of(context)!.importMostroUserInfo2),
              const SizedBox(height: 12),
              _buildInfoPoint(S.of(context)!.importMostroUserInfo3),
              const SizedBox(height: 24),
              Text(
                S.of(context)!.secretWordsLabel,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mnemonicController,
                minLines: 4,
                maxLines: 6,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                ),
                decoration: InputDecoration(
                  hintText: S.of(context)!.secretWordsPlaceholder,
                  hintStyle: TextStyle(
                    color: AppTheme.textSecondary.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  filled: true,
                  fillColor: AppTheme.backgroundInput,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: AppTheme.activeColor,
                      width: 2,
                    ),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(
                      color: Colors.red,
                      width: 2,
                    ),
                  ),
                  errorText: _errorMessage,
                  errorStyle: const TextStyle(
                    color: Colors.red,
                    fontSize: 12,
                  ),
                ),
                onChanged: (_) {
                  if (_errorMessage != null) {
                    setState(() {
                      _errorMessage = null;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      S.of(context)!.cancel,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _handleImport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.activeColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      S.of(context)!.importMostroUser,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text(
            '• ',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}