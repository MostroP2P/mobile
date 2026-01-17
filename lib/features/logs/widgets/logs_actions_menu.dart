import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:heroicons/heroicons.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_export_service.dart';
import 'package:mostro_mobile/services/logger_service.dart';

class LogsActionsMenu extends ConsumerWidget {
  final _logger = Logger();

  LogsActionsMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(logsProvider);
    final hasLogs = logs.isNotEmpty;

    return PopupMenuButton<String>(
      icon: const HeroIcon(
        HeroIcons.ellipsisVertical,
        style: HeroIconStyle.outline,
        color: AppTheme.cream1,
        size: 24,
      ),
      color: AppTheme.backgroundDark,
      onSelected: (value) => _handleMenuAction(context, ref, value, logs),
      itemBuilder: (context) => [
        _buildMenuItem(
          'save',
          HeroIcons.arrowDownTray,
          S.of(context)!.saveLogs,
          hasLogs ? AppTheme.cream1 : AppTheme.textSecondary,
          enabled: hasLogs,
        ),
        _buildMenuItem(
          'share',
          HeroIcons.share,
          S.of(context)!.shareLogs,
          hasLogs ? AppTheme.cream1 : AppTheme.textSecondary,
          enabled: hasLogs,
        ),
        _buildMenuItem(
          'clear',
          HeroIcons.trash,
          S.of(context)!.clearLogs,
          hasLogs ? AppTheme.statusError : AppTheme.textSecondary,
          enabled: hasLogs,
        ),
      ],
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    HeroIcons icon,
    String label,
    Color color, {
    bool enabled = true,
  }) {
    return PopupMenuItem(
      value: value,
      enabled: enabled,
      child: Row(
        children: [
          HeroIcon(
            icon,
            style: HeroIconStyle.outline,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: enabled ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMenuAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    List<LogEntry> logs,
  ) async {
    switch (action) {
      case 'save':
        await _saveLogsToFolder(context, ref, logs);
        break;
      case 'share':
        await _shareLogsFile(context, logs);
        break;
      case 'clear':
        await _showClearConfirmation(context, ref);
        break;
    }
  }

  Future<void> _saveLogsToFolder(
    BuildContext context,
    WidgetRef ref,
    List<LogEntry> logs,
  ) async {
    try {
      final filePath = await LoggerExportService.exportLogsToFolder(logs);

      if (filePath != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(S.of(context)!.logsExportSuccess),
            backgroundColor: AppTheme.statusSuccess,
          ),
        );
      }
    } catch (e, stackTrace) {
      _logger.e('Error exporting logs', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.of(context)!.logsExportError}: $e'),
            backgroundColor: AppTheme.statusError,
          ),
        );
      }
    }
  }

  Future<void> _shareLogsFile(BuildContext context, List<LogEntry> logs) async {
    try {
      final file = await LoggerExportService.exportLogsForSharing(logs);
      await LoggerExportService.shareLogs(file);
    } catch (e, stackTrace) {
      _logger.e('Error sharing logs', error: e, stackTrace: stackTrace);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${S.of(context)!.shareLogsError}: $e'),
            backgroundColor: AppTheme.statusError,
          ),
        );
      }
    }
  }

  Future<void> _showClearConfirmation(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundDark,
        title: Text(
          S.of(context)!.clearLogs,
          style: const TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          S.of(context)!.clearLogsConfirmation,
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              S.of(context)!.clear,
              style: const TextStyle(color: AppTheme.statusError),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      ref.read(logsProvider.notifier).clearLogs();
    }
  }
}
