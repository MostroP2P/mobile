import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/data/models/order.dart';
import 'package:mostro_mobile/data/repositories/mostro_storage.dart';
import 'package:mostro_mobile/shared/providers/mostro_database_provider.dart';

final mostroStorageProvider = Provider<MostroStorage>((ref) {
  final mostroDatabase = ref.watch(mostroDatabaseProvider);
  return MostroStorage(db: mostroDatabase);
});

final mostroMessageStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestMessage(orderId);
});

final mostroMessageHistoryProvider =
    StreamProvider.family<List<MostroMessage>, String>(
  (ref, orderId) {
    final storage = ref.read(mostroStorageProvider);
    return storage.watchAllMessages(orderId);
  },
);

final mostroOrderStreamProvider =
    StreamProvider.family<MostroMessage?, String>((ref, orderId) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestMessageOfType<Order>(orderId);
});

// Latest restore-session payload message (if any)
final restorePayloadStreamProvider =
    StreamProvider<MostroMessage?>((ref) {
  final storage = ref.read(mostroStorageProvider);
  return storage.watchLatestRestorePayload();
});
