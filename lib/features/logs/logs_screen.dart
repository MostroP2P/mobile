import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  Color _getLogColor(String line) {
    if (line.contains('ERROR') || line.contains('Exception') || line.contains('❌')) {
      return AppTheme.statusError;
    } else if (line.contains('WARN') || line.contains('⚠️')) {
      return AppTheme.statusWarning;
    } else if (line.contains('INFO') || line.contains('🟢') || line.contains('🚀')) {
      return AppTheme.statusInfo;
    } else {
      return AppTheme.textPrimary;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usa el provider reactivo de logs
    final logs = ref.watch(logsProvider).reversed.toList();
    final logsNotifier = ref.read(logsNotifierProvider.notifier);
    final s = S.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          s.logsScreenTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.backgroundDark,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textPrimary),
            tooltip: s.deleteLogsTooltip,
            onPressed: () async {
              await logsNotifier.clearLogs();
              // Invalida el provider para forzar actualización
              ref.invalidate(logsProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(s.logsDeletedMessage)),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppTheme.textPrimary),
            tooltip: s.shareLogsTooltip,
            onPressed: () async {
              final file = await logsNotifier.getLogFile(clean: true);
              if (file != null) {
                await Share.shareXFiles(
                  [XFile(file.path)],
                  text: s.logsShareText,
                );
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Error sharing logs')),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
        child: Text(
          s.noLogsMessage,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: logs.length,
        itemBuilder: (context, i) {
          final log = logs[i];
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard.withAlpha(180),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              log,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _getLogColor(log),
              ),
            ),
          );
        },
      ),
    );
  }
}