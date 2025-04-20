import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openMostroDatabase(String dbName) async {
  //var factory = getDatabaseFactory(packageName: dbName);
  //final db = await factory.openDatabase(dbName);

  final dir = await getApplicationSupportDirectory();
  final path = p.join(dir.path, 'mostro', 'databases', dbName);

  final db = await databaseFactoryIo.openDatabase(path);
  return db;
}

final mostroDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError();
});
