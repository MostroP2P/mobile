import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final logs = MemoryLogOutput.instance.getAllLogs();

    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          S.of(context)!.logsReport,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        iconTheme: const IconThemeData(color: AppTheme.textPrimary),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: logs.isEmpty ? null : _showClearConfirmation,
            tooltip: S.of(context)!.clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsHeader(logs.length),
          Expanded(
            child: logs.isEmpty
                ? _buildEmptyState()
                : _buildLogsList(logs),
          ),
          if (logs.isNotEmpty) _buildActionButtons(),
        ],
      ),
    );
  }

  Widget _buildStatsHeader(int count) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            S.of(context)!.totalLogs(count),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            S.of(context)!.maxEntries(1000),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.info_outline,
            size: 64,
            color: AppTheme.textInactive,
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.noLogsAvailable,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              S.of(context)!.logsWillAppearHere,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogsList(List<LogEntry> logs) {
    return ListView.builder(
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final color = _getLogLevelColor(log.level);
    final icon = _getLogLevelIcon(log.level);

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          log.message,
          style: const TextStyle(
            fontFamily: 'monospace',
            color: AppTheme.textPrimary,
            fontSize: 13,
          ),
        ),
        subtitle: Text(
          _formatTimestamp(log.timestamp),
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        border: Border(
          top: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isExporting ? null : _saveToDevice,
              icon: const Icon(Icons.save),
              label: Text(S.of(context)!.saveToDevice),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isExporting ? null : _shareLogs,
              icon: const Icon(Icons.share),
              label: Text(S.of(context)!.shareReport),
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogLevelColor(Level level) {
    switch (level) {
      case Level.error:
      case Level.fatal:
        return Colors.red;
      case Level.warning:
        return Colors.orange;
      case Level.info:
        return Colors.blue;
      case Level.debug:
      case Level.trace:
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  IconData _getLogLevelIcon(Level level) {
    switch (level) {
      case Level.error:
      case Level.fatal:
        return Icons.error_outline;
      case Level.warning:
        return Icons.warning_amber_outlined;
      case Level.info:
        return Icons.info_outline;
      case Level.debug:
      case Level.trace:
        return Icons.bug_report_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    return DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp);
  }

  Future<void> _shareLogs() async {
    setState(() => _isExporting = true);
    final exportTitle = S.of(context)!.logsExportTitle;
    final exportFailedMsg = S.of(context)!.exportFailed;

    try {
      final file = await _createLogFile();
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: exportTitle,
      );
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(exportFailedMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<void> _saveToDevice() async {
    setState(() => _isExporting = true);
    try {
      final file = await _createLogFile();
      final savedPath = await _saveToDocuments(file);

      if (mounted) {
        _showSuccessSnackBar(
          S.of(context)!.logsSavedTo(savedPath),
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(S.of(context)!.saveFailed);
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  Future<File> _createLogFile() async {
    final logs = MemoryLogOutput.instance.getAllLogs();
    final buffer = StringBuffer();

    buffer.writeln('Mostro Mobile - Logs Report');
    buffer.writeln('Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}');
    buffer.writeln('Total Entries: ${logs.length}');
    buffer.writeln('${'=' * 80}\n');

    for (final log in logs) {
      buffer.writeln(log.format());
    }

    final tempDir = await getTemporaryDirectory();
    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final file = File('${tempDir.path}/mostro_logs_$timestamp.txt');
    await file.writeAsString(buffer.toString());

    return file;
  }

  Future<String> _saveToDocuments(File tempFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final logsDir = Directory('${directory.path}/MostroLogs');
    await logsDir.create(recursive: true);

    final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    final destinationFile = File('${logsDir.path}/mostro_logs_$timestamp.txt');
    await tempFile.copy(destinationFile.path);

    return destinationFile.path;
  }

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        title: Text(
          S.of(context)!.clearLogsConfirmTitle,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          S.of(context)!.clearLogsConfirmMessage,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              S.of(context)!.cancel,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              MemoryLogOutput.instance.clear();
              Navigator.of(context).pop();
              setState(() {});
            },
            child: Text(
              S.of(context)!.clear,
              style: const TextStyle(
                color: AppTheme.statusError,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
