import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';

// Define possible states for logs
enum LogsState {
  loading,
  enabled,
  disabled
}

// Main service provider (reactive via ChangeNotifier)
final logsServiceProvider = ChangeNotifierProvider<LogsService>((ref) {
  final service = LogsService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

// Provider for reactive logs list
final logsProvider = Provider<UnmodifiableListView<String>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return service.logs;
});

// ELIMINADO: logsNotifierProvider ya no es necesario

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

// ELIMINADO: LogsNotifier class completa

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
    state = LogsState.loading;
    await _logsService.setLogsEnabled(enabled);
    state = enabled ? LogsState.enabled : LogsState.disabled;
  }

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
    state = LogsState.loading;
    await _logsService.setNativeLogsEnabled(enabled);
    state = enabled ? LogsState.enabled : LogsState.disabled;
  }

  bool get isEnabled => state == LogsState.enabled;
}