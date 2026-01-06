import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/logs/providers/logs_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
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
  Level? _selectedLevel;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final showButton = _scrollController.offset > 200 && maxScroll > 0;
      if (showButton != _showScrollToTop) {
        setState(() => _showScrollToTop = showButton);
      }
    }
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  List<LogEntry> _filterLogs(List<LogEntry> logs) {
    var filtered = logs;

    if (_selectedLevel != null) {
      filtered = filtered.where((log) => log.level == _selectedLevel).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((log) =>
        log.message.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
    }

    return filtered;
  }

  Future<void> _toggleLogging(bool value) async {
    if (value) {
      await _showPerformanceWarning();
    } else {
      await _disableLoggingAndSave();
    }
  }

  Future<void> _showPerformanceWarning() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: Text(
          S.of(context)!.performanceWarning,
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          S.of(context)!.performanceWarningMessage,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(S.of(context)!.enable),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      MemoryLogOutput.isLoggingEnabled = true;
      await ref.read(settingsProvider.notifier).updateLoggingEnabled(true);
    }
  }

  Future<void> _disableLoggingAndSave() async {
    // Only disable and clear - no saving (Phase 2)
    MemoryLogOutput.isLoggingEnabled = false;
    MemoryLogOutput.instance.clear();

    if (mounted) {
      await ref.read(settingsProvider.notifier).updateLoggingEnabled(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allLogs = ref.watch(logsProvider);
    final logs = _filterLogs(allLogs);

    return Stack(
      children: [
        Scaffold(
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
              _buildStatsHeader(allLogs.length, logs.length),
              _buildSearchBar(),
              _buildFilterChips(),
              Expanded(
                child: logs.isEmpty
                    ? _buildEmptyState()
                    : _buildLogsList(logs),
              ),
              _buildActionButtons(),
            ],
          ),
        ),
        if (_showScrollToTop && logs.isNotEmpty)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              mini: true,
              backgroundColor: AppTheme.activeColor,
              onPressed: _scrollToTop,
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatsHeader(int totalCount, int filteredCount) {
    final settings = ref.watch(settingsProvider);
    final isLoggingEnabled = settings.isLoggingEnabled;

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.logCapture,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLoggingEnabled
                          ? S.of(context)!.capturingLogs
                          : S.of(context)!.captureDisabled,
                      style: TextStyle(
                        color: isLoggingEnabled
                            ? AppTheme.activeColor
                            : AppTheme.textInactive,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: isLoggingEnabled,
                onChanged: _toggleLogging,
                activeTrackColor: AppTheme.activeColor,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                filteredCount == totalCount
                    ? S.of(context)!.totalLogs(totalCount)
                    : '$filteredCount / ${S.of(context)!.totalLogs(totalCount)}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                S.of(context)!.maxEntries(Config.logMaxEntries),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.backgroundCard,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: S.of(context)!.searchLogs,
          hintStyle: const TextStyle(color: AppTheme.textSecondary),
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.backgroundInput,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onChanged: (value) {
          setState(() => _searchQuery = value);
        },
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.backgroundCard,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(S.of(context)!.allLevels, null),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.errors, Level.error),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.warnings, Level.warning),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.info, Level.info),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.debug, Level.debug),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, Level? level) {
    final isSelected = _selectedLevel == level;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedLevel = selected ? level : null);
      },
      backgroundColor: AppTheme.backgroundInput,
      selectedColor: AppTheme.statusInfo.withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.statusInfo : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected ? AppTheme.statusInfo : Colors.white.withValues(alpha: 0.1),
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
      controller: _scrollController,
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[logs.length - 1 - index];
        return _buildLogItem(log);
      },
    );
  }

  Widget _buildLogItem(LogEntry log) {
    final color = _getLogLevelColor(log.level);
    final icon = _getLogLevelIcon(log.level);
    final levelStr = log.level.toString().split('.').last.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          levelStr,
                          style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '(${log.service}:${log.line})',
                        style: const TextStyle(
                          color: AppTheme.activeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    log.message,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(log.timestamp),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 18),
              color: AppTheme.textSecondary,
              onPressed: () => _copyLogToClipboard(log),
              tooltip: S.of(context)!.copyLog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyLogToClipboard(LogEntry log) async {
    await Clipboard.setData(ClipboardData(text: log.format()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context)!.logCopied),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _isExporting ? null : _shareLogs,
          icon: const Icon(Icons.share),
          label: Text(S.of(context)!.shareReport),
        ),
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
