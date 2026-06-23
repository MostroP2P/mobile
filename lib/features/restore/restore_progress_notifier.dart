import 'dart:async';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/features/restore/restore_progress_state.dart';

class RestoreProgressNotifier extends StateNotifier<RestoreProgressState> {
  Timer? _timeoutTimer;
  Timer? _autoHideTimer;
  static const _maxTimeout = Duration(seconds: 30);

  RestoreProgressNotifier() : super(RestoreProgressState.initial());

  bool get _canUpdateState => mounted;

  void _setStateSafely(RestoreProgressState newState) {
    if (!_canUpdateState) return;

    final schedulerPhase = WidgetsBinding.instance.schedulerPhase;
    if (schedulerPhase == SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_canUpdateState) {
          state = newState;
        }
      });
      return;
    }

    state = newState;
  }

  void startRestore() {
    logger.i('Starting restore overlay');
    _cancelAutoHideTimer();
    _setStateSafely(RestoreProgressState.initial().copyWith(
      isVisible: true,
      step: RestoreStep.requesting,
    ));

    _startTimeoutTimer();
  }

  void updateStep(RestoreStep step, {int? current, int? total}) {
    logger.i('Restore step: $step (${current ?? 0}/${total ?? 0})');
    _setStateSafely(state.copyWith(
      step: step,
      currentProgress: current ?? state.currentProgress,
      totalProgress: total ?? state.totalProgress,
    ));

    _resetTimeoutTimer();
  }

  void setOrdersReceived(int count) {
    logger.i('Received $count orders');
    _setStateSafely(state.copyWith(
      step: RestoreStep.receivingOrders,
      totalProgress: count,
      currentProgress: 0,
    ));

    _resetTimeoutTimer();
  }

  void incrementProgress() {
    _setStateSafely(state.copyWith(
      currentProgress: state.currentProgress + 1,
    ));

    _resetTimeoutTimer();
  }

  void completeRestore() {
    if (!_canUpdateState || state.step == RestoreStep.completed) return;

    logger.i('Restore completed successfully');
    _cancelTimeoutTimer();

    _setStateSafely(state.copyWith(
      step: RestoreStep.completed,
    ));

    // Auto-hide after 3 seconds (cancellable)
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        hide();
      }
    });
  }

  void completeAsNewUser() {
    if (!_canUpdateState || state.step == RestoreStep.completed) return;

    logger.i('Restore completed: no previous history for this Mostro');
    _cancelTimeoutTimer();

    _setStateSafely(state.copyWith(
      step: RestoreStep.completed,
      noHistoryFound: true,
    ));

    // Extended auto-hide so the user has time to read the secondary line.
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        hide();
      }
    });
  }

  void showError(String message) {
    if (!_canUpdateState || state.step == RestoreStep.error) return;

    logger.w('Restore error: $message');
    _cancelTimeoutTimer();

    _setStateSafely(state.copyWith(
      step: RestoreStep.error,
      errorMessage: message,
    ));

    // Auto-hide after 3 seconds (cancellable)
    _cancelAutoHideTimer();
    _autoHideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        hide();
      }
    });
  }

  void hide() {
    if (!_canUpdateState) return;

    logger.i('Hiding restore overlay');
    _cancelTimeoutTimer();
    _cancelAutoHideTimer();
    _setStateSafely(RestoreProgressState.initial());
  }

  void _startTimeoutTimer() {
    _cancelTimeoutTimer();
    _timeoutTimer = Timer(_maxTimeout, () {
      if (mounted && state.isVisible) {
        logger.w('Restore timeout - auto-hiding overlay');
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

  void _cancelAutoHideTimer() {
    _autoHideTimer?.cancel();
    _autoHideTimer = null;
  }

  @override
  void dispose() {
    _cancelTimeoutTimer();
    _cancelAutoHideTimer();
    super.dispose();
  }
}

final restoreProgressProvider =
    StateNotifierProvider<RestoreProgressNotifier, RestoreProgressState>((ref) {
  return RestoreProgressNotifier();
});
