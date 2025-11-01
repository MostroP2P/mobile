// lib/features/logs/logs_provider.dart
import 'dart:collection';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/logs/logs_service.dart';

// Provider principal del servicio (singleton)
final logsServiceProvider = Provider<LogsService>((ref) => LogsService());

// Provider para acceso directo a los logs (reactivo)
final logsProvider = Provider<UnmodifiableListView<String>>((ref) {
  final service = ref.watch(logsServiceProvider);
  return service.logs;
});

// Provider para el notifier (mantiene tu lógica actual)
final logsNotifierProvider =
StateNotifierProvider<LogsNotifier, List<String>>((ref) {
  return LogsNotifier(ref.read(logsServiceProvider));
});

// Provider para el estado del switch de logs Flutter
final logsEnabledProvider = StateNotifierProvider<LogsEnabledNotifier, bool>((ref) {
  return LogsEnabledNotifier(ref.read(logsServiceProvider));
});

// 👇 AGREGAR: Provider para el estado del switch de logs nativos
final nativeLogsEnabledProvider = StateNotifierProvider<NativeLogsEnabledNotifier, bool>((ref) {
  return NativeLogsEnabledNotifier(ref.read(logsServiceProvider));
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

// 👇 AGREGAR CLASE COMPLETA
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