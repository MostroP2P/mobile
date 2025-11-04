import 'dart:collection';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';

// Define possible states for logs
enum LogsState {
  loading,
  enabled,
  disabled
}

// Providers remain the same
final logsServiceProvider = ChangeNotifierProvider<LogsService>((ref) {
  final service = LogsService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

final logsProvider = Provider<UnmodifiableListView<String>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return service.logs;
});

final logsNotifierProvider =
StateNotifierProvider<LogsNotifier, List<String>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return LogsNotifier(service);
});

// Updated to use LogsState
final logsEnabledProvider = StateNotifierProvider<LogsEnabledNotifier, LogsState>((ref) {
  final service = ref.watch(logsServiceProvider);
  return LogsEnabledNotifier(service);
});

// Updated to use LogsState
final nativeLogsEnabledProvider = StateNotifierProvider<NativeLogsEnabledNotifier, LogsState>((ref) {
  final service = ref.watch(logsServiceProvider);
  return NativeLogsEnabledNotifier(service);
});

// LogsNotifier remains the same
class LogsNotifier extends StateNotifier<List<String>> {
  final LogsService _logsService;

  LogsNotifier(this._logsService) : super([]) {
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    state = _logsService.logs.toList();
  }

  Future<void> addLog(String message) async {
    _logsService.log(message);
    await _loadLogs();
  }

  Future<void> clearLogs({bool clean = true}) async {
    await _logsService.clearLogs(clean: clean);
    state = [];
  }

  Future<File?> getLogFile({bool clean = false}) async {
    return await _logsService.getLogFile(clean: clean);
  }
}

// Updated LogsEnabledNotifier to use LogsState
class LogsEnabledNotifier extends StateNotifier<LogsState> {
  final LogsService _logsService;

  LogsEnabledNotifier(this._logsService) : super(LogsState.loading) {
    _loadState();
  }

  Future<void> _loadState() async {
    final isEnabled = await _logsService.isLogsEnabled();
    state = isEnabled ? LogsState.enabled : LogsState.disabled;
  }

  Future<void> toggle(bool enabled) async {
    state = LogsState.loading; // Indicate that the state is changing
    await _logsService.setLogsEnabled(enabled);
    state = enabled ? LogsState.enabled : LogsState.disabled;
  }

  // Helper method to check if logs are enabled
  bool get isEnabled => state == LogsState.enabled;
}

// Updated NativeLogsEnabledNotifier to use LogsState
class NativeLogsEnabledNotifier extends StateNotifier<LogsState> {
  final LogsService _logsService;

  NativeLogsEnabledNotifier(this._logsService) : super(LogsState.loading) {
    _loadState();
  }

  Future<void> _loadState() async {
    final isEnabled = await _logsService.isNativeLogsEnabled();
    state = isEnabled ? LogsState.enabled : LogsState.disabled;
  }

  Future<void> toggle(bool enabled) async {
    state = LogsState.loading; // Indicate that the state is changing
    await _logsService.setNativeLogsEnabled(enabled);
    state = enabled ? LogsState.enabled : LogsState.disabled;
  }

  // Helper method to check if native logs are enabled
  bool get isEnabled => state == LogsState.enabled;
}
