import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';

class RestoreProgressNotifier extends StateNotifier<RestoreProgressState> {
  final _logger = Logger();
  Timer? _timeoutTimer;
  static const _maxTimeout = Duration(seconds: 30);

  RestoreProgressNotifier() : super(RestoreProgressState.initial());

  void startRestore() {
    _logger.i('Starting restore overlay');
    state = RestoreProgressState.initial().copyWith(
      isVisible: true,
      step: RestoreStep.requesting,
    );

    _startTimeoutTimer();
  }

  void updateStep(RestoreStep step, {int? current, int? total}) {
    _logger.i('Restore step: $step (${current ?? 0}/${total ?? 0})');
    state = state.copyWith(
      step: step,
      currentProgress: current ?? state.currentProgress,
      totalProgress: total ?? state.totalProgress,
    );

    _resetTimeoutTimer();
  }

  void setOrdersReceived(int count) {
    _logger.i('Received $count orders');
    state = state.copyWith(
      step: RestoreStep.receivingOrders,
      totalProgress: count,
      currentProgress: 0,
    );

    _resetTimeoutTimer();
  }

  void incrementProgress() {
    state = state.copyWith(
      currentProgress: state.currentProgress + 1,
    );

    _resetTimeoutTimer();
  }

  void completeRestore() {
    _logger.i('Restore completed successfully');
    _cancelTimeoutTimer();

    state = state.copyWith(
      step: RestoreStep.completed,
    );

    // Auto-hide after 1 second
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        hide();
      }
    });
  }

  void showError(String message) {
    _logger.w('Restore error: $message');
    _cancelTimeoutTimer();

    state = state.copyWith(
      step: RestoreStep.error,
      errorMessage: message,
    );

    // Auto-hide after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        hide();
      }
    });
  }

  void hide() {
    _logger.i('Hiding restore overlay');
    _cancelTimeoutTimer();
    state = RestoreProgressState.initial();
  }

  void _startTimeoutTimer() {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(_maxTimeout, () {
      if (mounted && state.isVisible) {
        _logger.w('Restore timeout - auto-hiding overlay');
        showError('Request timeout');
      }
    });
  }

  void _resetTimeoutTimer() {
    if (state.isVisible) {
      _startTimeoutTimer();
    }
  }

  void _cancelTimeoutTimer() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    super.dispose();
  }
}

final restoreProgressProvider =
    StateNotifierProvider<RestoreProgressNotifier, RestoreProgressState>((ref) {
  return RestoreProgressNotifier();
});