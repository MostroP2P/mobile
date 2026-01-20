import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/app_theme.dart';
import 'package:mostro_mobile/core/config.dart';
import 'package:mostro_mobile/features/logs/logs_provider.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/generated/l10n.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/utils/datetime_extensions_utils.dart';
import 'package:mostro_mobile/shared/utils/snack_bar_helper.dart';

class LogsScreen extends ConsumerStatefulWidget {
  const LogsScreen({super.key});

  @override
  ConsumerState<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends ConsumerState<LogsScreen> {
  String? _selectedLevel;
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
      final showButton = _scrollController.offset > 200 && maxScroll > 200;
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

  Future<void> _toggleLogging(bool value) async {
    if (value) {
      await _showPerformanceWarning();
    } else {
      await _disableLoggingAndSave();
    }
  }

  void _enableLogging() {
    MemoryLogOutput.isLoggingEnabled = true;
    ref.read(settingsProvider.notifier).updateLoggingEnabled(true);
  }

  void _disableLogging() {
    MemoryLogOutput.isLoggingEnabled = false;
    ref.read(settingsProvider.notifier).updateLoggingEnabled(false);
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
      _enableLogging();
    }
  }

  Future<void> _disableLoggingAndSave() async {
    if (mounted) {
      _disableLogging();
    }
  }

  Future<void> _showClearConfirmation() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.backgroundCard,
        title: Text(
          S.of(context)!.clearLogs,
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          S.of(context)!.clearLogsConfirmation,
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(S.of(context)!.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusError,
            ),
            child: Text(S.of(context)!.clear),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(logsProvider.notifier).clearLogs();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          SnackBarHelper.showTopSnackBar(
            context,
            S.of(context)!.logsCleared,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final isLoggingEnabled = settings.isLoggingEnabled;
    final filter = LogsFilter(
      levelFilter: _selectedLevel,
      searchQuery: _searchQuery,
    );
    final allLogs = ref.watch(logsProvider);
    final logs = ref.watch(filteredLogsProvider(filter));

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
          body: SafeArea(
            child: Column(
              children: [
                _buildStatsHeader(allLogs.length, logs.length, isLoggingEnabled),
                _buildSearchBar(),
                _buildFilterChips(),
                Expanded(
                  child: logs.isEmpty
                      ? _buildEmptyState()
                      : _buildLogsList(logs),
                ),
              ],
            ),
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

  Widget _buildStatsHeader(int totalCount, int filteredCount, bool isLoggingEnabled) {
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
                    setState(() {
                      _searchQuery = '';
                      _showScrollToTop = false;
                      if (_scrollController.hasClients) {
                        _scrollController.jumpTo(0);
                      }
                    });
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
          setState(() {
            _searchQuery = value;
            _showScrollToTop = false;
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
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
            _buildFilterChip(S.of(context)!.errors, 'error'),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.warnings, 'warning'),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.info, 'info'),
            const SizedBox(width: 8),
            _buildFilterChip(S.of(context)!.debug, 'debug'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String? levelFilter) {
    final isSelected = _selectedLevel == levelFilter;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedLevel = selected ? levelFilter : null;
          _showScrollToTop = false;
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        });
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
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.only(left: 8, right: 8, top: 8, bottom: bottomInset + 64),
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

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                log.level.toString().split('.').last.toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${log.service}:${log.line}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(log.timestamp),
                style: const TextStyle(
                  color: AppTheme.textInactive,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            log.message,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _getLogLevelColor(Level level) {
    switch (level) {
      case Level.error:
        return AppTheme.statusError;
      case Level.warning:
        return AppTheme.statusWarning;
      case Level.info:
        return AppTheme.statusInfo;
      case Level.debug:
        return AppTheme.textSecondary;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _getLogLevelIcon(Level level) {
    switch (level) {
      case Level.error:
        return Icons.error;
      case Level.warning:
        return Icons.warning;
      case Level.info:
        return Icons.info;
      case Level.debug:
        return Icons.bug_report;
      default:
        return Icons.circle;
    }
  }

  String _formatTime(DateTime timestamp) {
    return timestamp.timeAgoWithLocale(context);
  }
}
