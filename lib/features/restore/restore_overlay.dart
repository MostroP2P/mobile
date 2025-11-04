import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/restore/restore_progress_notifier.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class RestoreOverlay extends ConsumerWidget {
  const RestoreOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(restoreProgressProvider);

    if (!state.isVisible) {
      return const SizedBox.shrink();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 600;

    // Responsive values
    final horizontalMargin = isSmallScreen ? 24.0 : (isMediumScreen ? 32.0 : 40.0);
    final containerPadding = isSmallScreen ? 24.0 : 32.0;
    final iconSize = isSmallScreen ? 48.0 : 64.0;
    final titleFontSize = isSmallScreen ? 18.0 : 20.0;
    final messageFontSize = isSmallScreen ? 13.0 : 14.0;

    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: AppTheme.backgroundCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatusIcon(state.step, iconSize),
              SizedBox(height: isSmallScreen ? 16 : 24),
              Text(
                S.of(context)!.restoringOrders,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 12 : 16),
              Text(
                _getMessage(context, state),
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: messageFontSize,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isSmallScreen ? 16 : 24),
              _buildProgressIndicator(state, iconSize),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(RestoreStep step, double size) {
    IconData iconData;
    Color iconColor;

    switch (step) {
      case RestoreStep.error:
        iconData = Icons.error;
        iconColor = Colors.red;
        break;
      default:
        iconData = Icons.sync;
        iconColor = AppTheme.activeColor;
    }

    return Icon(
      iconData,
      size: size,
      color: iconColor,
    );
  }

  Widget _buildProgressIndicator(RestoreProgressState state, double iconSize) {
    if (state.step == RestoreStep.completed) {
      return const Icon(
        Icons.check_circle,
        color: Colors.green,
        size: 48,
      );
    }

    if (state.step == RestoreStep.error) {
      return const Icon(
        Icons.error,
        color: Colors.red,
        size: 48,
      );
    }

    // Show progress counter if we have total progress
    if (state.totalProgress > 0) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: AppTheme.activeColor,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${state.currentProgress}/${state.totalProgress}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    // Default spinning indicator
    return const SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        color: AppTheme.activeColor,
        strokeWidth: 3,
      ),
    );
  }

  String _getMessage(BuildContext context, RestoreProgressState state) {
    if (state.step == RestoreStep.error) {
      return state.errorMessage ?? S.of(context)!.restoreError;
    }

    switch (state.step) {
      case RestoreStep.requesting:
        return S.of(context)!.restoreRequestingData;
      case RestoreStep.receivingOrders:
        return S.of(context)!.restoreReceivingOrders;
      case RestoreStep.loadingDetails:
        return S.of(context)!.restoreLoadingDetails;
      case RestoreStep.processingRoles:
        return S.of(context)!.restoreProcessingRoles;
      case RestoreStep.finalizing:
        return S.of(context)!.restoreFinalizing;
      case RestoreStep.completed:
        return S.of(context)!.restoreCompleted;
      default:
        return S.of(context)!.restoreRequestingData;
    }
  }
}