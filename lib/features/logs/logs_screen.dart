import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/core/app_theme.dart';

class LogsScreen extends ConsumerWidget {
  const LogsScreen({super.key});

  Color _getLogColor(String line) {
    // 👇 AGREGAR: Detectar logs nativos primero
    if (line.contains('[NATIVE]')) {
      // Color específico para logs nativos de Android
      return const Color(0xFFFF9800); // Naranja para nativos
    }

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

  // 👇 AGREGAR: Método para obtener icono según tipo de log
  IconData _getLogIcon(String line) {
    if (line.contains('[NATIVE]')) {
      return Icons.android;
    } else if (line.contains('ERROR') || line.contains('❌')) {
      return Icons.error_outline;
    } else if (line.contains('WARN') || line.contains('⚠️')) {
      return Icons.warning_amber;
    } else if (line.contains('🚀')) {
      return Icons.rocket_launch;
    } else {
      return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          final logColor = _getLogColor(log);
          final logIcon = _getLogIcon(log); // 👈 USAR NUEVO MÉTODO

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 4),
            padding: const EdgeInsets.symmetric(
              vertical: 8,
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: AppTheme.backgroundCard.withAlpha(180),
              borderRadius: BorderRadius.circular(8),
              // 👇 AGREGAR: Borde izquierdo de color para mejor distinción
              border: Border(
                left: BorderSide(
                  color: logColor,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 👇 AGREGAR: Icono indicador
                Icon(
                  logIcon,
                  size: 16,
                  color: logColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: logColor,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}