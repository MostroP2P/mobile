import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class FormSection extends StatelessWidget {
  final String title;
  final Widget icon;
  final Color iconBackgroundColor;
  final Widget child;
  final Widget? extraContent;
  final String? infoTooltip;
  final String? infoTitle;
  final Widget? topRightWidget;

  const FormSection({
    super.key,
    required this.title,
    required this.icon,
    required this.iconBackgroundColor,
    required this.child,
    this.extraContent,
    this.infoTooltip,
    this.infoTitle,
    this.topRightWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 14,
                    ),
                    softWrap: true,
                    maxLines: null,
                  ),
                ),
                if (infoTooltip != null) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () => _showInfoDialog(context, infoTitle ?? title, infoTooltip!),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Icon(
                        Icons.info_outline,
                        size: 14,
                        color: AppTheme.textSubtle,
                      ),
                    ),
                  ),
                ],
                if (topRightWidget != null) ...[
                  const SizedBox(width: 8),
                  topRightWidget!,
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBackgroundColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: icon),
                ),
                const SizedBox(width: 16),
                Expanded(child: child),
              ],
            ),
          ),
          if (extraContent != null) extraContent!,
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ],
      ),
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppTheme.backgroundCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            content,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                S.of(context)!.ok,
                style: const TextStyle(
                  color: AppTheme.activeColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
