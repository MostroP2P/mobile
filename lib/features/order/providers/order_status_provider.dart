import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/core/mostro_fsm.dart';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/mostro_message.dart';
import 'package:mostro_mobile/shared/providers/mostro_storage_provider.dart';

/// Exposes a live [Status] stream for a given order based on the full history
/// of stored `MostroMessage`s.  Any new message automatically recomputes the
/// status using the canonical [MostroFSM].
final orderStatusProvider = StreamProvider.family<Status, String>((ref, orderId) {
  final storage = ref.watch(mostroStorageProvider);

  Status computeStatus(Iterable<MostroMessage> messages) {
    var status = Status.pending; // default starting point
    for (final m in messages) {
      status = MostroFSM.nextStatus(status, m.action);
    }
    return status;
  }

  return storage
      .watchAllMessages(orderId) // emits list whenever new message saved
      .map((messages) => computeStatus(messages))
      .distinct();
});
