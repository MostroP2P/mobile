import 'package:logger/logger.dart';

/// Entry representing a single log message
class LogEntry {
  final DateTime timestamp;
  final Level level;
  final String message;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
  });

  /// Format log entry as readable string
  String format() {
    final time = timestamp.toIso8601String();
    final levelStr = level.toString().split('.').last.toUpperCase();
    return '[$time] [$levelStr] $message';
  }
}

/// Custom LogOutput that captures all logs to memory buffer
class MemoryLogOutput extends LogOutput {
  static final MemoryLogOutput instance = MemoryLogOutput._();

  MemoryLogOutput._();

  final List<LogEntry> _buffer = [];
  static const int _maxEntries = 1000;

  @override
  void output(OutputEvent event) {
    for (String line in event.lines) {
      _buffer.add(LogEntry(
        timestamp: DateTime.now(),
        level: event.level,
        message: _sanitize(line),
      ));

      if (_buffer.length > _maxEntries) {
        _buffer.removeAt(0);
      }
    }
  }

  /// Remove sensitive data from log messages
  String _sanitize(String message) {
    return message
        .replaceAll(RegExp(r'nsec[0-9a-z]+'), '[PRIVATE_KEY]')
        .replaceAll(RegExp(r'npub[0-9a-z]+'), '[PUBLIC_KEY]')
        .replaceAll(RegExp(r'"privateKey"\s*:\s*"[^"]*"'), '"privateKey":"[REDACTED]"')
        .replaceAll(RegExp(r'"mnemonic"\s*:\s*"[^"]*"'), '"mnemonic":"[REDACTED]"')
        .replaceAll(RegExp(r'[0-9a-f]{64}'), '[HEX_KEY]');
  }

  /// Get all captured logs
  List<LogEntry> getAllLogs() => List.unmodifiable(_buffer);

  /// Clear all logs
  void clear() => _buffer.clear();

  /// Get log count
  int get logCount => _buffer.length;
}

/// Multi-output that writes to both console and memory
class _MultiOutput extends LogOutput {
  final ConsoleOutput consoleOutput;
  final MemoryLogOutput memoryOutput;

  _MultiOutput(this.consoleOutput, this.memoryOutput);

  @override
  void output(OutputEvent event) {
    consoleOutput.output(event);
    memoryOutput.output(event);
  }
}

/// Simple printer that shows clean logs without decorations
class SimplePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final time = _formatTime(event.time);
    final level = _formatLevel(event.level);
    final message = event.message.toString();

    // Extract class name from stack trace if available
    String? className;
    if (event.stackTrace != null) {
      className = _extractClassName(event.stackTrace!);
    }

    final prefix = className != null ? '[$className]' : '';

    return ['$prefix $time $level - $message'];
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
           '${time.minute.toString().padLeft(2, '0')}:'
           '${time.second.toString().padLeft(2, '0')}';
  }

  String _formatLevel(Level level) {
    switch (level) {
      case Level.error:
        return '[ERROR]';
      case Level.warning:
        return '[WARN]';
      case Level.info:
        return '[INFO]';
      case Level.debug:
        return '[DEBUG]';
      case Level.trace:
        return '[TRACE]';
      default:
        return '[LOG]';
    }
  }

  String? _extractClassName(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    if (lines.isEmpty) return null;

    // Try to extract class name from first line
    final match = RegExp(r'#\d+\s+(\w+)\.').firstMatch(lines[0]);
    return match?.group(1);
  }
}

/// Shared logger instance that captures to memory and console
/// Use this instead of creating new Logger() instances
final logger = Logger(
  printer: SimplePrinter(),
  output: _MultiOutput(
    ConsoleOutput(),
    MemoryLogOutput.instance,
  ),
  level: Level.debug,
);
