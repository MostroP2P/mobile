import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';

Future<Database> openMostroDatabase() async {
  var factory = getDatabaseFactory();
  final db = await factory.openDatabase('mostro.db');
  return db;
}

final mostroDatabaseProvider = Provider<Database>((ref) {
  throw UnimplementedError();
});
