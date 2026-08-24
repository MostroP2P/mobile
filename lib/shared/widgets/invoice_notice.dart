import 'package:flutter/material.dart';
import 'package:mostro_mobile/core/app_theme.dart';

/// A boxed notice about the terms of a settlement, shown above the flow it
/// qualifies on the add- and pay-invoice screens.
///
/// The accent carries the whole of the distinction the user has to make:
/// [InvoiceNotice.refusal] is red and means the screen will not proceed,
/// [InvoiceNotice.caution] is yellow and means it will, with something the
/// app could not confirm on the user's behalf.
class InvoiceNotice extends StatelessWidget {
  final Color accent;
  final String title;
  final String body;

  const InvoiceNotice({
    super.key,
    required this.accent,
    required this.title,
    required this.body,
  });

  /// Something is wrong with the terms and the screen will not act on them.
  const InvoiceNotice.refusal({
    Key? key,
    required String title,
    required String body,
  }) : this(
          key: key,
          accent: AppTheme.statusError,
          title: title,
          body: body,
        );

  /// Nothing is known to be wrong, but a check the app would normally make
  /// could not be made.
  const InvoiceNotice.caution({
    Key? key,
    required String title,
    required String body,
  }) : this(
          key: key,
          accent: AppTheme.statusWarning,
          title: title,
          body: body,
        );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accent,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
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
