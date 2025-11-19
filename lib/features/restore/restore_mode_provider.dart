import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider that manages the restore mode state
///
/// When true, blocks all old message processing in AbstractMostroNotifier
/// to prevent state updates during the restore process.
///
/// This replaces the previous static mutable flag with proper Riverpod state management.
final isRestoringProvider = StateProvider<bool>((ref) => false);
