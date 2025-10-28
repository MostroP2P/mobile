import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';


final logsProvider = ChangeNotifierProvider<LogsService>((ref) {
  return LogsService()..init();
});

class LogsService extends ChangeNotifier {
  final List<String> _logs = [];
  late File _logFile;
  IOSink? _sink;
  bool _initialized = false;
  DebugPrintCallback? _previousDebugPrint;

  List<String> get logs => _logs;

  Future<void> init() async {
    if (_initialized) return;


    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/mostro_logs.txt');

    // Load previous logs if present
    if (await _logFile.exists()) {
      final content = await _logFile.readAsLines();
      _logs.addAll(content);
      if (content.isNotEmpty) notifyListeners();
      _initialized = true;
    }

    _sink = _logFile.openWrite(mode: FileMode.append);

    // Intercept debugPrint to persist all logs (and still print in debug).
    _previousDebugPrint ??= debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      final time = DateTime.now().toIso8601String();
      final line = "[$time] ${message ?? ''}";
      try {
        _logs.add(line);
        _sink?.writeln(line); // keep original emojis/colors
        // Avoid flushing every line; rely on OS buffering.
        notifyListeners();
      } catch (e, st) {
        // Fallback to the original debugPrint to avoid recursion and crashes.
        _previousDebugPrint?.call('[LogsService] Error writing log: $e');
        _previousDebugPrint?.call(st.toString());
      } finally {
        if (kDebugMode) {
          // Also print to console in debug builds.
          // Preserve wrapWidth by delegating to the original if available.
          _previousDebugPrint?.call(line, wrapWidth: wrapWidth);
        }
      }
    };
  }

  Future<void> clearLogs() async {
    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    _logs.clear();
    await _logFile.writeAsString('');

    _sink = _logFile.openWrite(mode: FileMode.append);

    await _writeLog('🧹 Logs cleared by user');
  }

  @protected
  Future<void> _writeLog(String message) async {
    if (_sink == null) {
      _previousDebugPrint?.call('[LogsService] ⚠️ Sink uninitialized: $message');
      return;
    }

    try {
      final timestamp = DateTime.now().toIso8601String();
      final line = '[$timestamp] $message';
      _logs.add(line);
      _sink!.writeln(line);
      await _sink!.flush();
      notifyListeners();
    } catch (e, stackTrace) {
      _previousDebugPrint?.call('[LogsService] ❌ Write error: $e');
      _previousDebugPrint?.call(stackTrace.toString());
    }
  }

  /// Returns the log file.
  /// If [clean] is true, emojis and non-printable characters are removed.
  Future<File> getLogFile({bool clean = false}) async {
    await _sink?.flush();

    if (clean) {
      final cleanLines = _logs.map((line) => _cleanLine(line)).toList();
      final cleanFile = File(_logFile.path.replaceFirst('.txt', '_clean.txt'));
      await cleanFile.writeAsString(cleanLines.join('\n'));
      return cleanFile;
    }

    return _logFile;
  }

  /// Removes emojis and non-printable characters, keeping only visible text
  String _cleanLine(String line) {
    final ansi = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
    final noAnsi = line.replaceAll(ansi, '');
    return noAnsi.replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

  }

  @override
  void dispose() {
    unawaited(_sink?.flush());
    _sink?.close();
    _sink = null;

    if (_previousDebugPrint != null) {
      debugPrint = _previousDebugPrint!;
      _previousDebugPrint = null;
    }

    super.dispose();
  }
}
