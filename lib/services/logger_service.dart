import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';

class LogEntry {
  final DateTime timestamp;
  final Level level;
  final String message;
  final String service;
  final String line;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    required this.service,
    required this.line,
  });

  String format() {
    final time = timestamp.toString().substring(0, 19);
    final levelStr = level.toString().split('.').last.toUpperCase();
    return '[$levelStr]($service:$line) $time - $message';
  }
}

/// Custom LogOutput that captures all logs to memory buffer
class MemoryLogOutput extends LogOutput {
  static final MemoryLogOutput instance = MemoryLogOutput._();

  MemoryLogOutput._();

  final List<LogEntry> _buffer = [];
  final SimplePrinter _printer = SimplePrinter();

  @override
  void output(OutputEvent event) {
    final formattedLines = _printer.log(LogEvent(
      event.level,
      event.origin.message,
      time: event.origin.time,
      error: event.origin.error,
      stackTrace: event.origin.stackTrace,
    ));

    if (formattedLines.isNotEmpty) {
      final formattedLine = formattedLines[0];
      final serviceAndLine = _extractFromFormattedLine(formattedLine);

      _buffer.add(LogEntry(
        timestamp: event.origin.time,
        level: event.level,
        message: _cleanMessage(event.origin.message.toString()),
        service: serviceAndLine['service'] ?? 'App',
        line: serviceAndLine['line'] ?? '0',
      ));

      if (_buffer.length > Config.logMaxEntries) {
        _buffer.removeRange(0, Config.logBatchDeleteSize);
      }
    }
  }

  Map<String, String> _extractFromFormattedLine(String line) {
    final match = RegExp(r'\[(?:ERROR|WARN|INFO|DEBUG|TRACE)\]\((\w+):(\d+)\)').firstMatch(line);
    if (match != null) {
      return {
        'service': match.group(1) ?? 'App',
        'line': match.group(2) ?? '0'
      };
    }
    return {'service': 'App', 'line': '0'};
  }

  String _cleanMessage(String message) {
    var cleaned = message;
    cleaned = cleaned
        .replaceAll(RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), '')
        .replaceAll(RegExp(r'\[\d+m'), '')
        .replaceAll(RegExp(r'\[38;5;\d+m'), '')
        .replaceAll(RegExp(r'\[39m'), '')
        .replaceAll(RegExp(r'\[2m'), '')
        .replaceAll(RegExp(r'\[22m'), '')
        .replaceAll(RegExp(r'[┌┐└┘├┤─│┬┴┼╭╮╰╯╔╗╚╝╠╣═║╦╩╬━┃┄├]'), '')
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), '')
        .replaceAll(RegExp(r'nsec[0-9a-z]+'), '[PRIVATE_KEY]')
        .replaceAll(RegExp(r'npub[0-9a-z]+'), '[PUBLIC_KEY]')
        .replaceAll(RegExp(r'"privateKey"\s*:\s*"[^"]*"'), '"privateKey":"[REDACTED]"')
        .replaceAll(RegExp(r'"mnemonic"\s*:\s*"[^"]*"'), '"mnemonic":"[REDACTED]"')
        .replaceAll(RegExp(r'[0-9a-f]{64}'), '[HEX]')
        .replaceAll(RegExp(r'[^A-Za-z0-9\s.:,!?\-_/\[\]]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  List<LogEntry> getAllLogs() => List.unmodifiable(_buffer);
  void clear() => _buffer.clear();
  int get logCount => _buffer.length;
}

class _ConsoleOnlyOutput extends LogOutput {
  @override
  void output(OutputEvent event) {
    for (final line in event.lines) {
      // ignore: avoid_print
      print(line);
    }
  }
}

class _MultiOutput extends LogOutput {
  final MemoryLogOutput memoryOutput;
  final LogOutput consoleOutput;

  _MultiOutput(this.memoryOutput, this.consoleOutput);

  @override
  void output(OutputEvent event) {
    memoryOutput.output(event);
    consoleOutput.output(event);
  }
}

class SimplePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final level = _formatLevel(event.level);
    final message = event.message.toString();
    final timestamp = event.time.toString().substring(0, 19);
    final stackTrace = event.stackTrace ?? StackTrace.current;
    final serviceAndLine = _extractFromStackTrace(stackTrace);
    final service = serviceAndLine['service'] ?? 'App';
    final line = serviceAndLine['line'] ?? '0';

    return [
      '[$level]($service:$line) $timestamp - $message',
    ];
  }

  String _formatLevel(Level level) {
    switch (level) {
      case Level.error:
        return 'ERROR';
      case Level.warning:
        return 'WARN';
      case Level.info:
        return 'INFO';
      case Level.debug:
        return 'DEBUG';
      case Level.trace:
        return 'TRACE';
      default:
        return 'LOG';
    }
  }

  Map<String, String> _extractFromStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) return {'service': 'App', 'line': '0'};

    final lines = stackTrace.toString().split('\n');
    Map<String, String>? lastValid;

    for (final line in lines) {
      if (line.contains('logger_service.dart') ||
          line.contains('logger.dart') ||
          line.contains(' (dart:') ||
          line.contains('<asynchronous suspension>') ||
          line.trim().isEmpty) {
        continue;
      }

      var match = RegExp(r'#\d+\s+\S+\s+\((?:package:[\w_]+/)?(?:.*/)(\w+)\.dart:(\d+)').firstMatch(line);
      if (match != null) {
        lastValid = {
          'service': match.group(1) ?? 'App',
          'line': match.group(2) ?? '0'
        };
        continue;
      }

      match = RegExp(r'package:[\w_]+/(?:.*/)(\w+)\.dart:(\d+)').firstMatch(line);
      if (match != null) {
        lastValid = {
          'service': match.group(1) ?? 'App',
          'line': match.group(2) ?? '0'
        };
      }
    }

    return lastValid ?? {'service': 'App', 'line': '0'};
  }
}

class _AlwaysStackTraceFilter extends LogFilter {
  @override
  bool shouldLog(LogEvent event) => true;
}

Logger? _cachedSimpleLogger;
Logger? _cachedFullLogger;

Logger get logger {
  if (Config.fullLogsInfo) {
    _cachedFullLogger ??= Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
      ),
      output: _MultiOutput(MemoryLogOutput.instance, ConsoleOutput()),
      level: Level.debug,
    );
    return _cachedFullLogger!;
  } else {
    _cachedSimpleLogger ??= Logger(
      printer: SimplePrinter(),
      output: _MultiOutput(MemoryLogOutput.instance, _ConsoleOnlyOutput()),
      level: Level.debug,
      filter: _AlwaysStackTraceFilter(),
    );
    return _cachedSimpleLogger!;
  }
}

