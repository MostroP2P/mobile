// lib/features/logs/logs_provider.dart
import 'dart:collection';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';

// Reactive ChangeNotifier service provider with proper lifecycle management
final logsServiceProvider = ChangeNotifierProvider<LogsService>((ref) {
  final service = LogsService();

  // Cleanup when provider is disposed
  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

// Provider for direct reactive access to logs
final logsProvider = Provider<UnmodifiableListView<String>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return service.logs;
});

// Provider for the notifier (maintains current logic)
final logsNotifierProvider =
StateNotifierProvider<LogsNotifier, List<String>>((ref) {
  final service = ref.watch(logsServiceProvider);

  // Listen to service changes and update state
  ref.listen<LogsService>(logsServiceProvider, (previous, next) {
    // This will trigger when the service notifies listeners
  });

  return LogsNotifier(service);
});

// Provider for Flutter logs switch state
final logsEnabledProvider = StateNotifierProvider<LogsEnabledNotifier, bool>((ref) {
  final service = ref.watch(logsServiceProvider);
  return LogsEnabledNotifier(service);
});

// Provider for native logs switch state
final nativeLogsEnabledProvider = StateNotifierProvider<NativeLogsEnabledNotifier, bool>((ref) {
  final service = ref.watch(logsServiceProvider);
  return NativeLogsEnabledNotifier(service);
});

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
    // The service will call notifyListeners(), so state will update automatically
    await _loadLogs();
  }

  Future<void> clearLogs({bool clean = true}) async {
    await _logsService.clearLogs(clean: clean);
    // The service will call notifyListeners()
    state = [];
  }

  Future<File?> getLogFile({bool clean = false}) async {
    return await _logsService.getLogFile(clean: clean);
  }
}

class LogsEnabledNotifier extends StateNotifier<bool> {
  final LogsService _logsService;

  LogsEnabledNotifier(this._logsService) : super(true) {
    _loadState();
  }

  Future<void> _loadState() async {
    state = await _logsService.isLogsEnabled();
  }

  Future<void> toggle(bool enabled) async {
    await _logsService.setLogsEnabled(enabled);
    state = enabled;
  }
}

// NativeLogsEnabledNotifier class
class NativeLogsEnabledNotifier extends StateNotifier<bool> {
  final LogsService _logsService;

  NativeLogsEnabledNotifier(this._logsService) : super(true) {
    _loadState();
  }

  Future<void> _loadState() async {
    state = await _logsService.isNativeLogsEnabled();
  }

  Future<void> toggle(bool enabled) async {
    await _logsService.setNativeLogsEnabled(enabled);
    state = enabled;
  }
}