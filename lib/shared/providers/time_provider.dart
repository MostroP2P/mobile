import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits a new DateTime every 30 seconds to trigger UI updates
final timeProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});
