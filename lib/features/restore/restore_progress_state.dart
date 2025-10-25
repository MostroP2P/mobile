enum RestoreStep {
  requesting,
  receivingOrders,
  loadingDetails,
  processingRoles,
  finalizing,
  completed,
  error,
}

class RestoreProgressState {
  final RestoreStep step;
  final int currentProgress;
  final int totalProgress;
  final String? errorMessage;
  final bool isVisible;

  const RestoreProgressState({
    required this.step,
    this.currentProgress = 0,
    this.totalProgress = 0,
    this.errorMessage,
    this.isVisible = false,
  });

  RestoreProgressState copyWith({
    RestoreStep? step,
    int? currentProgress,
    int? totalProgress,
    String? errorMessage,
    bool? isVisible,
  }) {
    return RestoreProgressState(
      step: step ?? this.step,
      currentProgress: currentProgress ?? this.currentProgress,
      totalProgress: totalProgress ?? this.totalProgress,
      errorMessage: errorMessage ?? this.errorMessage,
      isVisible: isVisible ?? this.isVisible,
    );
  }

  double get progressPercentage {
    if (totalProgress == 0) return 0.0;
    return currentProgress / totalProgress;
  }

  static RestoreProgressState initial() {
    return const RestoreProgressState(
      step: RestoreStep.requesting,
      isVisible: false,
    );
  }
}
