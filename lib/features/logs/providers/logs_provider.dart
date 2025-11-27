import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';

/// Provider that exposes all captured logs
final logsProvider = Provider<List<LogEntry>>((ref) {
  return MemoryLogOutput.instance.getAllLogs();
});

/// Provider for log count
final logCountProvider = Provider<int>((ref) {
  return MemoryLogOutput.instance.logCount;
});
