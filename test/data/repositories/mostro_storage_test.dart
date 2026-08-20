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

    test(
        'concurrent addMessage calls for the same key: only the first-started '
        'write is retained, the second is a no-op', () async {
      final first = MostroMessage(
        action: Action.fiatSent,
        id: 'order-3',
        receivedAt: 1111,
      );
      final second = MostroMessage(
        action: Action.fiatSent,
        id: 'order-3',
        receivedAt: 2222,
      );

      // Neither call is awaited before the other starts, so their
      // exists-check-then-write sequences genuinely overlap; the
      // transaction wrapping addMessage is what keeps this deterministic.
      final firstCall = storage.addMessage('key-3', first);
      final secondCall = storage.addMessage('key-3', second);
      await Future.wait([firstCall, secondCall]);

      final reloaded = await storage.getLatestMessageById('order-3');

      expect(reloaded, isNotNull);
      expect(reloaded!.receivedAt, 1111);
    });
  });
}
