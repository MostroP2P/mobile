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

  List<String> get logs => _logs;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final dir = await getApplicationDocumentsDirectory();
    _logFile = File('${dir.path}/mostro_logs.txt');

    // Cargar logs previos si existen
    if (await _logFile.exists()) {
      final content = await _logFile.readAsLines();
      _logs.addAll(content);
    }

    _sink = _logFile.openWrite(mode: FileMode.append);

    // Interceptar debugPrint para guardar todos los logs
    debugPrint = (String? message, {int? wrapWidth}) {
      final time = DateTime.now().toIso8601String();
      final line = "[$time] ${message ?? ''}";
      _logs.add(line);
      _sink?.writeln(line); // guardar con emojis/colores originales
      _sink?.flush();
      notifyListeners();

      // Mostrar en consola
      if (kDebugMode) {
        print(line);
      }
    };
  }

  Future<void> clearLogs() async {
    await _writeLog('🧹 Logs cleared by user');
    _logs.clear();
    await _logFile.writeAsString('');
    notifyListeners();
  }

  @protected
  // Called indirectly by the debugPrint override
  Future<void> _writeLog(String message) async {
    if (_sink == null) {
      debugPrint('[LogsService] ⚠️ Sink no inicializado: $message');
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
      debugPrint('[LogsService] ❌ Error escribiendo log: $e');
      debugPrint(stackTrace.toString());
    }
  }

  /// Retorna el archivo de logs.
  /// Si [clean] = true, se eliminan emojis y caracteres no imprimibles
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

  String _cleanLine(String line) {
    // Quita emojis y caracteres no imprimibles, dejando solo texto visible
    return line.replaceAll(RegExp(r'[^\x20-\x7E]'), '');
  }

  @override
  void dispose() {
    _sink?.close();
    super.dispose();
  }
}
