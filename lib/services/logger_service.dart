import 'dart:async';
import 'dart:isolate';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/core/config.dart';

// Isolate log communication
ReceivePort? _isolateLogReceiver;
SendPort? _isolateLogSender;

const isolatePortName = 'mostro_logger_send_port';

/// Initialize receiver to collect logs from background isolates
void initIsolateLogReceiver() {
  if (_isolateLogReceiver != null) return;

  _isolateLogReceiver = ReceivePort();
  _isolateLogSender = _isolateLogReceiver!.sendPort;

  // Register the SendPort so background isolates can look it up
  IsolateNameServer.removePortNameMapping(isolatePortName);
  IsolateNameServer.registerPortWithName(_isolateLogSender!, isolatePortName);

  _isolateLogReceiver!.listen((message) {
    if (message is Map<String, dynamic>) {
      try {
        addLogFromIsolate(message);
      } catch (e, stack) {
        // ignore: avoid_print
        print('ERROR: Failed to process isolate log message: $e');
        // ignore: avoid_print
        print('Stack trace: $stack');
      }
    }
  });
}

SendPort? get isolateLogSenderPort => _isolateLogSender;

// Precompiled once: cleanMessage runs for every stored log line and used to
// build 14 RegExp objects per call.
final List<(RegExp, String)> _sanitizers = [
  (RegExp(r'\x1B\[[0-9;]*[a-zA-Z]'), ''),
  (RegExp(r'\[\d+m'), ''),
  (RegExp(r'\[38;5;\d+m'), ''),
  (RegExp(r'\[39m'), ''),
  (RegExp(r'\[2m'), ''),
  (RegExp(r'\[22m'), ''),
  (RegExp(r'[┌┐└┘├┤─│┬┴┼╭╮╰╯╔╗╚╝╠╣═║╦╩╬━┃┄├]'), ''),
  (RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true), ''),
  (RegExp(r'nsec[0-9a-z]+'), '[PRIVATE_KEY]'),
  (RegExp(r'"privateKey"\s*:\s*"[^"]*"'), '"privateKey":"[REDACTED]"'),
  (RegExp(r'"mnemonic"\s*:\s*"[^"]*"'), '"mnemonic":"[REDACTED]"'),
  (RegExp(r'[^A-Za-z0-9\s.:,!?\-_/\[\]]'), ' '),
  (RegExp(r'\s+'), ' '),
];

String cleanMessage(String message) {
  var cleaned = message;
  for (final (pattern, replacement) in _sanitizers) {
    cleaned = cleaned.replaceAll(pattern, replacement);
  }
  return cleaned.trim();
}

void addLogFromIsolate(Map<String, dynamic> logData) {
  if (!MemoryLogOutput.isLoggingEnabled) return;

  DateTime timestamp;
  try {
    final timestampStr = logData['timestamp'];
    if (timestampStr == null) {
      timestamp = DateTime.now();
    } else {
      timestamp = DateTime.parse(timestampStr.toString());
    }
  } catch (e) {
    timestamp = DateTime.now();
  }

  final levelStr = logData['level']?.toString() ?? 'debug';
  final level = _levelFromString(levelStr);
  final rawMessage = logData['message']?.toString() ?? '';
  final message = cleanMessage(rawMessage);
  final service = logData['service']?.toString() ?? 'Background';
  final line = logData['line']?.toString() ?? '0';

  MemoryLogOutput.instance.addEntry(LogEntry(
    timestamp: timestamp,
    level: level,
    message: message,
    service: service,
    line: line,
  ));
}

Level _levelFromString(String level) {
  switch (level) {
    case 'error': return Level.error;
    case 'warning': return Level.warning;
    case 'info': return Level.info;
    case 'debug': return Level.debug;
    case 'trace': return Level.trace;
    default: return Level.debug;
  }
}

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

class MemoryLogOutput extends LogOutput with ChangeNotifier {
  static final MemoryLogOutput instance = MemoryLogOutput._();

  MemoryLogOutput._();

  final List<LogEntry> _buffer = [];
  final SimplePrinter _printer = SimplePrinter();

  static bool isLoggingEnabled = false;

  @override
  void output(OutputEvent event) {
    if (!isLoggingEnabled) return;

    final stackTrace = event.origin.stackTrace ?? StackTrace.current;
    final serviceAndLine = _printer.extractFromStackTrace(stackTrace);

    addEntry(LogEntry(
      timestamp: event.origin.time,
      level: event.level,
      message: cleanMessage(event.origin.message.toString()),
      service: serviceAndLine['service'] ?? 'Unknown',
      line: serviceAndLine['line'] ?? '0',
    ));
  }

  List<LogEntry> getAllLogs() => List.unmodifiable(_buffer);

  void clear() {
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _buffer.clear();
    notifyListeners();
  }

  /// Listener notifications are coalesced: one per [notifyInterval] instead
  /// of one per line. LogsNotifier copies the whole buffer on every
  /// notification, so per-line notifications made each log line O(buffer).
  static const Duration notifyInterval = Duration(milliseconds: 250);
  Timer? _notifyTimer;

  void _scheduleNotify() {
    _notifyTimer ??= Timer(notifyInterval, () {
      _notifyTimer = null;
      notifyListeners();
    });
  }

  void addEntry(LogEntry entry) {
    _buffer.add(entry);
    _maintainBufferSize();
    _scheduleNotify();
  }

  void _maintainBufferSize() {
    if (_buffer.length > Config.logMaxEntries) {
      final deleteCount = _buffer.length < Config.logBatchDeleteSize
          ? _buffer.length - Config.logMaxEntries
          : Config.logBatchDeleteSize;
      if (deleteCount > 0) {
        _buffer.removeRange(0, deleteCount);
      }
    }
  }

  int get logCount => _buffer.length;
}

class _MultiOutput extends LogOutput {
  final MemoryLogOutput memoryOutput;
  final LogOutput? consoleOutput;

  _MultiOutput(this.memoryOutput, this.consoleOutput);

  @override
  void output(OutputEvent event) {
    memoryOutput.output(event);
    consoleOutput?.output(event);
  }
}

class SimplePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) {
    final level = _formatLevel(event.level);
    final message = event.message.toString();
    final timestamp = event.time.toString().substring(0, 19);
    final stackTrace = event.stackTrace ?? StackTrace.current;
    final serviceAndLine = extractFromStackTrace(stackTrace);
    final service = serviceAndLine['service'] ?? 'Unknown';
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

  Map<String, String> extractFromStackTrace(StackTrace? stackTrace) {
    if (stackTrace == null) return {'service': 'Unknown', 'line': '0'};

    final lines = stackTrace.toString().split('\n');

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
        return {
          'service': match.group(1) ?? 'Unknown',
          'line': match.group(2) ?? '0'
        };
      }

      match = RegExp(r'package:[\w_]+/(?:.*/)(\w+)\.dart:(\d+)').firstMatch(line);
      if (match != null) {
        return {
          'service': match.group(1) ?? 'Unknown',
          'line': match.group(2) ?? '0'
        };
      }
    }

    return {'service': 'Unknown', 'line': '0'};
  }
}

/// Gate for every log call. In non-verbose (release) builds nothing is
/// processed unless the user enabled in-app logging, and even then the
/// configured [level] is honoured — the previous filter ignored it, so
/// enabling logging turned every `logger.d` on a hot path into stack-trace
/// capture plus sanitising work.
class MostroLogFilter extends LogFilter {
  MostroLogFilter({bool? verbose}) : verbose = verbose ?? Config.verboseLogging;

  final bool verbose;

  @override
  bool shouldLog(LogEvent event) {
    if (!verbose && !MemoryLogOutput.isLoggingEnabled) return false;
    final minLevel = level ?? Level.trace;
    return event.level.index >= minLevel.index;
  }
}

/// The pretty console printer captures and formats a stack trace per call; it
/// is pure cost when there is no console attached, so non-verbose builds use
/// a printer that emits nothing (the in-memory sink reads `event.origin`).
LogPrinter buildLogPrinter({bool? verbose}) {
  if (verbose ?? Config.verboseLogging) {
    return PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    );
  }
  return _NoopPrinter();
}

/// Emits a single constant sentinel line instead of formatting anything.
///
/// It cannot return an empty list: `Logger.log` only forwards to the
/// configured `LogOutput` when the printer produced at least one line
/// (`logger/src/logger.dart`, `if (output.isNotEmpty)`), so an empty result
/// would starve [MemoryLogOutput] and leave the in-app Logs screen empty in
/// release builds. The line itself is never read — [MemoryLogOutput] rebuilds
/// the entry from `event.origin`, and no console output is attached in
/// non-verbose builds — so a `const` list keeps the no-formatting, no-stack-
/// capture, zero-allocation behaviour.
class _NoopPrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) => const [''];
}

Logger? _cachedLogger;

Logger get logger {
  _cachedLogger ??= Logger(
    printer: buildLogPrinter(),
    output: _MultiOutput(
      MemoryLogOutput.instance,
      Config.verboseLogging ? ConsoleOutput() : null,
    ),
    level: Config.verboseLogging ? Level.debug : Level.warning,
    filter: MostroLogFilter(),
  );
  return _cachedLogger!;
}

/// Log wrapper for isolated Dart entry points (e.g., FCM background handler)
/// where the main logger singleton is unavailable because the
/// IsolateNameServer port has not been registered.
///
/// All background-isolate logging should go through this function instead of
/// calling debugPrint directly, so the convention is centralized and easy to
/// upgrade if cross-isolate logging becomes possible in the future.
void backgroundLog(String message) {
  debugPrint('[BackgroundIsolate] ${cleanMessage(message)}');
}

class IsolateLogOutput extends LogOutput {
  final SendPort? sendPort;

  IsolateLogOutput(this.sendPort);

  @override
  void output(OutputEvent event) {
    if (Config.isDebug) {
      for (final line in event.lines) {
        // ignore: avoid_print
        print(line);
      }
    }

    if (sendPort != null) {
      final printer = SimplePrinter();
      final serviceAndLine = printer.extractFromStackTrace(event.origin.stackTrace);

      final rawMessage = event.origin.message.toString();
      final sanitizedMessage = cleanMessage(rawMessage);

      sendPort!.send({
        'timestamp': event.origin.time.toIso8601String(),
        'level': event.level.name,
        'message': sanitizedMessage,
        'service': serviceAndLine['service'] ?? 'Background',
        'line': serviceAndLine['line'] ?? '0',
      });
    }
  }
}
