// lib/features/logs/logs_service.dart
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'native_log_service.dart'; // 👈 AGREGAR

class LogsService {
  static final LogsService _instance = LogsService._internal();
  factory LogsService() => _instance;
  LogsService._internal();

  static const String _logsEnabledKey = 'logs_enabled';
  static const String _nativeLogsEnabledKey = 'native_logs_enabled'; // 👈 NUEVO

  final List<String> _logs = [];
  File? _logFile;
  IOSink? _sink;
  bool _initialized = false;
  bool _isEnabled = true;
  bool _nativeLogsEnabled = true; // 👈 NUEVO

  // 👇 AGREGAR: Servicio de logs nativos
  final NativeLogService _nativeLogService = NativeLogService();
  StreamSubscription? _nativeSubscription;

  // Expose unmodifiable view to prevent external mutation
  UnmodifiableListView<String> get logs => UnmodifiableListView(_logs);

  Future<void> init() async {
    if (_initialized) return;

    try {
      // Load preferences
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool(_logsEnabledKey) ?? true;
      _nativeLogsEnabled = prefs.getBool(_nativeLogsEnabledKey) ?? true; // 👈 NUEVO

      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/mostro_logs.txt');

      // Load existing logs if file exists
      if (await _logFile!.exists()) {
        final content = await _logFile!.readAsString();
        _logs.addAll(content.split('\n').where((line) => line.isNotEmpty));
      }

      // Open file for appending
      _sink = _logFile!.openWrite(mode: FileMode.append);

      // 👇 AGREGAR: Iniciar captura de logs nativos
      if (_nativeLogsEnabled) {
        _initNativeLogsCapture();
      }

      // Set initialized flag only after successful setup
      _initialized = true;
    } catch (e) {
      print('Error initializing LogsService: $e');
      rethrow;
    }
  }

  // 👇 AGREGAR MÉTODO COMPLETO
  void _initNativeLogsCapture() {
    try {
      _nativeSubscription = _nativeLogService.nativeLogStream.listen(
            (nativeLog) {
          if (!_isEnabled || !_nativeLogsEnabled) return;

          // Formatear log nativo con prefijo
          final timestamp = DateTime.now().toIso8601String();
          final line = '[$timestamp] [NATIVE] $nativeLog';

          _logs.add(line);

          try {
            _sink?.writeln(line);
          } catch (e) {
            print('Error escribiendo log nativo: $e');
          }
        },
        onError: (error) {
          print('❌ Error en stream de logs nativos: $error');
        },
      );

      log('🔧 Captura de logs nativos iniciada');
    } catch (e) {
      print('❌ Error iniciando captura de logs nativos: $e');
    }
  }

  // Get current state
  Future<bool> isLogsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_logsEnabledKey) ?? true;
  }

  // 👇 AGREGAR MÉTODO NUEVO
  Future<bool> isNativeLogsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nativeLogsEnabledKey) ?? true;
  }

  // Change state
  Future<void> setLogsEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logsEnabledKey, enabled);
  }

  // 👇 AGREGAR MÉTODO NUEVO
  Future<void> setNativeLogsEnabled(bool enabled) async {
    _nativeLogsEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nativeLogsEnabledKey, enabled);

    if (enabled && _nativeSubscription == null) {
      _initNativeLogsCapture();
    } else if (!enabled && _nativeSubscription != null) {
      await _nativeSubscription?.cancel();
      _nativeSubscription = null;
      log('🔧 Captura de logs nativos detenida');
    }
  }

  // Main logging method - compatible with both old (writeLog) and new (log) usage
  void log(String message) {
    if (!_initialized || !_isEnabled) return;

    final timestamp = DateTime.now().toIso8601String();
    final line = '[$timestamp] $message';

    _logs.add(line);

    try {
      _sink?.writeln(line);
    } catch (e) {
      print('Error writing to log file: $e');
    }
  }

  // Alias for backwards compatibility
  Future<void> writeLog(String message) async {
    log(message);
  }

  // Read logs (backwards compatibility)
  Future<List<String>> readLogs() async {
    return _logs.toList();
  }

  Future<void> clearLogs({bool clean = true}) async {
    if (!_initialized) return;

    try {
      // Close current sink
      await _sink?.close();

      // Clear file
      await _logFile?.writeAsString('');

      // Clear memory list
      _logs.clear();

      // Reopen sink
      _sink = _logFile?.openWrite(mode: FileMode.append);
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }

  Future<File?> getLogFile({bool clean = false}) async {
    if (!_initialized || _logFile == null) return null;

    try {
      // Flush before reading to ensure all data is written
      await _sink?.flush();

      if (!clean) {
        return _logFile;
      }

      // Create cleaned copy
      final dir = await getApplicationDocumentsDirectory();
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

  String _cleanLine(String line) {
    // Remove ANSI color codes (e.g., \x1B[31m for red)
    final ansiRegex = RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]');
    final noAnsi = line.replaceAll(ansiRegex, '');

    // Remove non-printable control characters but keep Unicode text
    final controlCharsRegex = RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]');
    return noAnsi.replaceAll(controlCharsRegex, '');
  }

  Future<void> dispose() async {
    if (_initialized) {
      await _sink?.flush();
      await _sink?.close();

      // 👇 AGREGAR: Limpiar servicio de logs nativos
      await _nativeSubscription?.cancel();
      _nativeLogService.dispose();

      _initialized = false;
    }
  }
}