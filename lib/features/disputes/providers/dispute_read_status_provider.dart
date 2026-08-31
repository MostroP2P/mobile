import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/features/disputes/notifiers/dispute_chat_notifier.dart';
import 'package:mostro_mobile/services/dispute_read_status_service.dart';

/// Provider to track when disputes are marked as read
/// This triggers UI updates when a dispute's read status changes
final disputeReadStatusProvider = StateProvider.family<int, String>((ref, disputeId) {
  return DateTime.now().millisecondsSinceEpoch;
});

/// Whether the dispute chat has admin messages newer than the read cursor.
/// Replaces a per-row FutureBuilder whose future (a prefs read) was recreated
/// on every rebuild. Watching [disputeReadStatusProvider] recomputes it when
/// the dispute is marked as read.
final disputeHasUnreadProvider =
    FutureProvider.family<bool, String>((ref, disputeId) async {
  ref.watch(disputeReadStatusProvider(disputeId));
  final messages = ref.watch(
    disputeChatNotifierProvider(disputeId).select((s) => s.messages),
  );
  if (messages.isEmpty) return false;
  final isFromUser =
      ref.read(disputeChatNotifierProvider(disputeId).notifier).isFromUser;
  return DisputeReadStatusService.hasUnreadMessages(
    disputeId,
    messages,
    isFromUser: isFromUser,
  );
});
