import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast_io.dart';

Future<Database> openMostroDatabase(String dbName) async {
  //var factory = getDatabaseFactory(packageName: dbName);
  //final db = await factory.openDatabase(dbName);
  final db = await databaseFactoryIo.openDatabase(dbName);
  return db;
}

final mostroDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError();
});
