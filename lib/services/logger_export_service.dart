import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mostro_mobile/services/logger_service.dart';

class LoggerExportService {
  static String _generateFilename() {
    final now = DateTime.now();
    final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}-${now.second.toString().padLeft(2, '0')}';
    return 'mostro_logs_$timestamp.txt';
  }

  static String _logsToText(List<LogEntry> logs) {
    if (logs.isEmpty) return 'No logs available\n';

    final buffer = StringBuffer();
    buffer.writeln('Mostro P2P Application Logs');
    buffer.writeln('Generated: ${DateTime.now()}');
    buffer.writeln('Total logs: ${logs.length}');
    buffer.writeln('${'=' * 60}\n');

    for (final log in logs) {
      buffer.writeln(log.format());
    }

    return buffer.toString();
  }

  static Future<String?> exportLogsToFolder(List<LogEntry> logs) async {
    final filename = _generateFilename();
    final content = _logsToText(logs);
    final bytes = Uint8List.fromList(utf8.encode(content));

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Logs',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['txt'],
      bytes: bytes,
    );

    return result;
  }

  static Future<File> exportLogsForSharing(List<LogEntry> logs) async {
    final tempDir = await getTemporaryDirectory();
    final filename = _generateFilename();
    final filePath = p.join(tempDir.path, filename);
    final file = File(filePath);

    final content = _logsToText(logs);
    await file.writeAsString(content);

    return file;
  }

  static Future<void> shareLogs(File file) async {
    final xFile = XFile(file.path);
    await Share.shareXFiles(
      [xFile],
      subject: 'Mostro P2P Logs',
      text: 'Application logs from Mostro P2P',
    );
  }
}
