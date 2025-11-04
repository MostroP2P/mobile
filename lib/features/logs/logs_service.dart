import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_log_service.dart';

class LogsService extends ChangeNotifier {
  static final LogsService _instance = LogsService._internal();
  factory LogsService() => _instance;
  LogsService._internal();

  static const String _logsEnabledKey = 'logs_enabled';
  static const String _nativeLogsEnabledKey = 'native_logs_enabled';
  static const String _logFileName = 'mostro_logs.txt';
  static const int _maxLogLines = 5000;

  final List<String> _logs = [];
  File? _logFile;
  IOSink? _sink;
  bool _initialized = false;
  bool _isDisposed = false;
  bool _isEnabled = true;
  bool _nativeLogsEnabled = true;

  // Native log service
  final NativeLogService _nativeLogService = NativeLogService();
  StreamSubscription? _nativeSubscription;

  // Expose unmodifiable view to prevent external mutation
  UnmodifiableListView<String> get logs => UnmodifiableListView(_logs);

  /// Initialize the logs service
  Future<void> init() async {
    if (_initialized || _isDisposed) return;

    try {
      // Load preferences
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_logsEnabledKey) ?? true;
      _nativeLogsEnabled = prefs.getBool(_nativeLogsEnabledKey) ?? true;

      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/$_logFileName');

      // Load existing logs if file exists
      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        final lines = content.split('\n').where((line) => line.isNotEmpty).toList();

        // Keep only last N lines to prevent memory bloat
        if (lines.length > _maxLogLines) {
          _logs.addAll(lines.skip(lines.length - _maxLogLines));
        } else {
          _logs.addAll(lines);
        }

        // Notify after loading existing logs
        notifyListeners();
      }

      // Open file for appending
      _sink = _logFile!.openWrite(mode: FileMode.append);

      // Start native logs capture
      if (_nativeLogsEnabled) {
        _initNativeLogsCapture();
      }

      // Set initialized flag only after successful setup
      _initialized = true;

      log('🚀 LogsService initialized');
    } catch (e) {
      print('Error initializing LogsService: $e');
      rethrow;
    }
  }

  /// Initialize native logs capture
  void _initNativeLogsCapture() {
    if (_isDisposed) return;

    try {
      _nativeSubscription = _nativeLogService.nativeLogStream.listen(
            (nativeLog) {
          if (_isDisposed || !_isEnabled || !_nativeLogsEnabled) return;

          // Format native log with prefix
          final timestamp = DateTime.now().toIso8601String();
          final line = '[$timestamp] [NATIVE] $nativeLog';

          _logs.add(line);

          // Keep only last N lines in memory
          if (_logs.length > _maxLogLines) {
            _logs.removeAt(0);
          }

          try {
            _sink?.writeln(line);
          } catch (e) {
            print('Error writing native log: $e');
          }

          // Notify listeners about new native log
          notifyListeners();
        },
        onError: (error) {
          print('❌ Error in native logs stream: $error');
        },
      );

      log('🔧 Native logs capture started');
    } catch (e) {
      print('❌ Error starting native logs capture: $e');
    }
  }

  /// Get current logs enabled state
  Future<bool> isLogsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_logsEnabledKey) ?? true;
  }

  /// Get native logs enabled state
  Future<bool> isNativeLogsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nativeLogsEnabledKey) ?? true;
  }

  /// Set logs enabled state
  Future<void> setLogsEnabled(bool enabled) async {
    if (_isDisposed) return;

    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logsEnabledKey, enabled);

    // Notify listeners about state change
    notifyListeners();
  }

  /// Set native logs enabled state
  Future<void> setNativeLogsEnabled(bool enabled) async {
    if (_isDisposed) return;

    _nativeLogsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nativeLogsEnabledKey, enabled);

    if (enabled && _nativeSubscription == null) {
      _initNativeLogsCapture();
    } else if (!enabled && _nativeSubscription != null) {
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
      log('🔧 Native logs capture stopped');
    }

    // Notify listeners about state change
    notifyListeners();
  }

  /// Main logging method
  void log(String message) {
    if (!_initialized || _isDisposed || !_isEnabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';

    _logs.add(line);

    // Keep only last N lines in memory
    if (_logs.length > _maxLogLines) {
      _logs.removeAt(0);
    }

    try {
      _sink?.writeln(line);
    } catch (e) {
      print('Error writing to log file: $e');
    }

    // Notify listeners about new log
    notifyListeners();
  }

  /// Alias for backwards compatibility
  Future<void> writeLog(String message) async {
    log(message);
  }

  /// Read logs (backwards compatibility)
  Future<List<String>> readLogs() async {
    return _logs.toList();
  }

  /// Clear all logs
  Future<void> clearLogs({bool clean = true}) async {
    if (!_initialized || _isDisposed) return;

    try {
      // Close current sink
      await _sink?.close();

      // Clear file
      if (clean && _logFile != null && await _logFile!.exists()) {
        await _logFile!.writeAsString('');
      }

      // Clear memory list
      _logs.clear();

      // Reopen sink if not disposed
      if (!_isDisposed) {
        _sink = _logFile?.openWrite(mode: FileMode.append);
      }

      // Notify listeners about cleared logs
      notifyListeners();
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }

  /// Get the log file for sharing
  Future<File?> getLogFile({bool clean = false}) async {
    if (!_initialized || _isDisposed || _logFile == null) return null;

    try {
      // Flush before reading to ensure all data is written
      await _sink?.flush();

      if (!clean) {
        return _logFile;
      }

      // Create cleaned copy
      final dir = await getTemporaryDirectory();
      final cleanFile = File('${dir.path}/mostro_logs_clean.txt');

      final content = await _logFile!.readAsString();
      final cleanedLines = content
          .split('\n')
          .where((line) => line.isNotEmpty)
          .map(_cleanLine)
          .join('\n');

      await cleanFile.writeAsString(cleanedLines);
      return cleanFile;
    } catch (e) {
      print('Error getting log file: $e');
      return null;
    }
  }

  /// Clean a log line by removing ANSI codes and control characters
  String _cleanLine(String line) {
    // Remove ANSI color codes (e.g., \x1B[31m for red)
    final ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
    final noAnsi = line.replaceAll(ansiRegex, '');

    // Remove non-printable control characters but keep Unicode text
    final controlCharsRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
    return noAnsi.replaceAll(controlCharsRegex, '');
  }

  /// Dispose method for cleanup
  @override
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    try {
      // Stop native log capture
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
      _nativeLogService.dispose();

      // Flush and close file sink
      await _sink?.flush();
      await _sink?.close();
      _sink = null;

      // Clear logs from memory
      _logs.clear();

      // Reset state
      _logFile = null;
      _initialized = false;

      // Call parent dispose
      super.dispose();
    } catch (e) {
      print('Error disposing LogsService: $e');
    }
  }
}