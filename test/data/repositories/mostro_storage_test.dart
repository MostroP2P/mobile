import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';

void main() {
  late MostroStorage storage;

  setUp(() async {
    final db = await databaseFactoryMemory.openDatabase('mostro_storage_test.db');
    storage = MostroStorage(db: db);
  });

  group('MostroStorage.addMessage receivedAt persistence', () {
    test('write-once: a second addMessage call for the same key does not '
        'overwrite the original receivedAt', () async {
      final first = MostroMessage(
        action: Action.fiatSent,
        id: 'order-2',
        receivedAt: 1000,
      );
      final second = MostroMessage(
        action: Action.fiatSent,
        id: 'order-2',
        receivedAt: 9999,
      );

      await storage.addMessage('key-2', first);
      await storage.addMessage('key-2', second);

      final reloaded = await storage.getLatestMessageById('order-2');

      expect(reloaded, isNotNull);
      expect(reloaded!.receivedAt, 1000);
    });
  });
}
