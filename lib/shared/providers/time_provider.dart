import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Emits a new DateTime every 30 seconds to trigger UI updates
final timeProvider = StreamProvider<DateTime>((ref) {
  return Stream<DateTime>.periodic(
    const Duration(seconds: 30),
    (_) => DateTime.now(),
  );
});

/// Provides a more efficient countdown timer using Timer.periodic
/// with automatic cleanup and debouncing
final countdownTimeProvider = StreamProvider<DateTime>((ref) {
  late StreamController<DateTime> controller;
  Timer? timer;
  DateTime? lastEmittedTime;

  controller = StreamController<DateTime>.broadcast(
    onListen: () {
      // Start timer when first listener subscribes
      timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        final now = DateTime.now();
        // Debounce: only emit if seconds have actually changed
        if (lastEmittedTime == null || 
            now.second != lastEmittedTime!.second ||
            now.minute != lastEmittedTime!.minute ||
            now.hour != lastEmittedTime!.hour) {
          lastEmittedTime = now;
          controller.add(now);
        }
      });
      // Emit initial value immediately
      final now = DateTime.now();
      lastEmittedTime = now;
      controller.add(now);
    },
    onCancel: () {
      // Cleanup timer when last listener unsubscribes
      timer?.cancel();
      timer = null;
      lastEmittedTime = null;
    },
  );

  // Ensure cleanup when provider is disposed
  ref.onDispose(() {
    timer?.cancel();
    controller.close();
  });

  return controller.stream;
});
