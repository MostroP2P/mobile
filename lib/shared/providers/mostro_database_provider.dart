import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openMostroDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  await dir.create(recursive: true);
  final dbPath = join(dir.path, 'mostro.db');

  final db = await databaseFactoryIo.openDatabase(dbPath);
  return db;
}

final mostroDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError();
});
