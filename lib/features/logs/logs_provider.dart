import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/services/logger_service.dart';

final logsProvider = StateNotifierProvider<LogsNotifier, List<LogEntry>>((ref) {
  return LogsNotifier();
});

class LogsNotifier extends StateNotifier<List<LogEntry>> {
  LogsNotifier() : super([]) {
    MemoryLogOutput.instance.addListener(_onLogsChanged);
    _onLogsChanged();
  }

  void _onLogsChanged() {
    state = MemoryLogOutput.instance.getAllLogs();
  }

  void clearLogs() {
    MemoryLogOutput.instance.clear();
  }

  @override
  void dispose() {
    MemoryLogOutput.instance.removeListener(_onLogsChanged);
    super.dispose();
  }
}

final filteredLogsProvider = Provider.family<List<LogEntry>, LogsFilter>((ref, filter) {
  final logs = ref.watch(logsProvider);

  var filteredLogs = logs;

  if (filter.levelFilter != null && filter.levelFilter != 'all') {
    final level = _stringToLevel(filter.levelFilter!);
    filteredLogs = filteredLogs.where((log) => log.level == level).toList();
  }

  if (filter.searchQuery.isNotEmpty) {
    final query = filter.searchQuery.toLowerCase();
    filteredLogs = filteredLogs.where((log) {
      return log.message.toLowerCase().contains(query) ||
             log.service.toLowerCase().contains(query);
    }).toList();
  }

  return filteredLogs;
});

Level _stringToLevel(String levelStr) {
  switch (levelStr) {
    case 'error': return Level.error;
    case 'warning': return Level.warning;
    case 'info': return Level.info;
    case 'debug': return Level.debug;
    default: return Level.debug;
  }
}

class LogsFilter {
  final String? levelFilter;
  final String searchQuery;

  const LogsFilter({
    this.levelFilter,
    this.searchQuery = '',
  });

  LogsFilter copyWith({
    String? levelFilter,
    String? searchQuery,
  }) {
    return LogsFilter(
      levelFilter: levelFilter ?? this.levelFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}
