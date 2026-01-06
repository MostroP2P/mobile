import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';

/// Provider that exposes the MemoryLogOutput as a ChangeNotifier
final memoryLogOutputProvider = ChangeNotifierProvider<MemoryLogOutput>((ref) {
  return MemoryLogOutput.instance;
});

/// Provider that exposes all captured logs reactively
final logsProvider = Provider<List<LogEntry>>((ref) {
  ref.watch(memoryLogOutputProvider);
  return MemoryLogOutput.instance.getAllLogs();
});

/// Provider for log count reactively
final logCountProvider = Provider<int>((ref) {
  ref.watch(memoryLogOutputProvider);
  return MemoryLogOutput.instance.logCount;
});
