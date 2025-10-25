import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mostro_mobile/generated/l10n.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  Color _getLogColor(String line, BuildContext context) {
    final theme = Theme.of(context);
    if (line.contains('ERROR') || line.contains('Exception')) {
      return Colors.redAccent.shade200;
    } else if (line.contains('WARN') || line.contains('⚠️')) {
      return Colors.amberAccent.shade200;
    } else if (line.contains('INFO') || line.contains('🟢')) {
      return theme.colorScheme.secondary;
    } else {
      return theme.brightness == Brightness.dark
          ? Colors.grey.shade300
          : Colors.grey.shade900;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsService = ref.watch(logsProvider);
    final logs = logsService.logs.reversed.toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Guardar la localización antes de cualquier await
    final s = S.of(context)!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          s.logsScreenTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.primary),
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          color: theme.colorScheme.onSurface,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: s.deleteLogsTooltip,
            onPressed: () async {
              await logsService.clearLogs();
              // BuildContext seguro porque s ya está capturado
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(s.logsDeletedMessage)),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: s.shareLogsTooltip,
            onPressed: () async {
              final file = await logsService.getLogFile(clean: true);
              await Share.shareXFiles([XFile(file.path)], text: s.logsShareText);
            },
          ),
        ],
      ),
      body: logs.isEmpty
          ? Center(
        child: Text(
          s.noLogsMessage,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
            padding:
            const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.grey.withAlpha(179) // reemplaza withOpacity
                  : Colors.grey.shade200.withAlpha(179),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              log,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: _getLogColor(log, context),
              ),
            ),
          );
        },
      ),
    );
  }
}
