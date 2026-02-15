import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';

/// Widget that displays a Lightning Address confirmation step before
/// automatically sending it to Mostro.
///
/// Shows the configured Lightning Address and lets the user confirm
/// or fall back to manual invoice input. This ensures users always
/// know what address will receive their sats.
class LnAddressConfirmationWidget extends StatelessWidget {
  /// The Lightning Address to confirm.
  final String lightningAddress;

  /// Callback when the user confirms the Lightning Address.
  final VoidCallback onConfirm;

  /// Callback when the user wants to enter an invoice manually instead.
  final VoidCallback onManualFallback;

  const LnAddressConfirmationWidget({
    super.key,
    required this.lightningAddress,
    required this.onConfirm,
    required this.onManualFallback,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.dark1,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.mostroGreen.withAlpha(128)),
          ),
          child: Column(
            children: [
              const Icon(
                LucideIcons.zap,
                color: AppTheme.mostroGreen,
                size: 40,
              ),
              const SizedBox(height: 16),
              Text(
                S.of(context)!.lnAddressConfirmTitle,
                style: const TextStyle(
                  color: AppTheme.mostroGreen,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppTheme.backgroundDark,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: Text(
                  lightningAddress,
                  style: const TextStyle(
                    color: AppTheme.cream1,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'monospace',
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                S.of(context)!.lnAddressConfirmDescription,
                style: TextStyle(
                  color: AppTheme.cream1.withAlpha(153),
                  fontSize: 13,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(LucideIcons.checkCircle, size: 20),
                  label: Text(
                    S.of(context)!.lnAddressConfirmButton,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.mostroGreen,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onManualFallback,
          icon: const Icon(LucideIcons.edit, size: 16),
          label: Text(S.of(context)!.lnAddressEnterManually),
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.cream1.withAlpha(179),
          ),
        ),
      ],
    );
  }
}
