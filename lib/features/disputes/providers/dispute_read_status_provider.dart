import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider to track when disputes are marked as read
/// This triggers UI updates when a dispute's read status changes
final disputeReadStatusProvider = StateProvider.family<int, String>((ref, disputeId) {
  return DateTime.now().millisecondsSinceEpoch;
});
