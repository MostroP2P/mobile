import 'package:flutter/material.dart';

/// Helper class to show SnackBars at the top of the screen
/// This ensures the bottom navigation bar remains accessible at all times
class SnackBarHelper {
  /// Shows a SnackBar at the top of the screen
  ///
  /// [context] - BuildContext for showing the SnackBar
  /// [message] - Text message to display
  /// [duration] - How long to show the SnackBar (default: 2 seconds)
  /// [backgroundColor] - Optional background color for the SnackBar
  static void showTopSnackBar(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
  }) {
    final mediaQuery = MediaQuery.of(context);
    final messenger = ScaffoldMessenger.of(context);

    _showSnackBarInternal(
      messenger: messenger,
      screenHeight: mediaQuery.size.height,
      statusBarHeight: mediaQuery.padding.top,
      message: message,
      duration: duration,
      backgroundColor: backgroundColor,
    );
  }

  /// Async-safe version for showing SnackBar after async gaps.
  /// Capture context values before await and pass them here.
  static void showTopSnackBarAsync({
    required ScaffoldMessengerState messenger,
    required double screenHeight,
    required double statusBarHeight,
    required String message,
    Duration duration = const Duration(seconds: 2),
    Color? backgroundColor,
  }) {
    _showSnackBarInternal(
      messenger: messenger,
      screenHeight: screenHeight,
      statusBarHeight: statusBarHeight,
      message: message,
      duration: duration,
      backgroundColor: backgroundColor,
    );
  }

  /// Shared internal logic for both sync and async SnackBar methods
  static void _showSnackBarInternal({
    required ScaffoldMessengerState messenger,
    required double screenHeight,
    required double statusBarHeight,
    required String message,
    Duration? duration,
    Color? backgroundColor,
  }) {
    // Calculate positioning using system values
    final appBarHeight = kToolbarHeight; // Standard AppBar height (56px)
    final extraMargin = 4.0; // Minimal margin for tighter spacing
    final topMargin = statusBarHeight + appBarHeight + extraMargin;

    final estimatedSnackBarHeight = 60.0; // Estimated height optimized for 1-2 line messages
    final bottomMargin = screenHeight - topMargin - estimatedSnackBarHeight;

    // Clear any existing SnackBars to prevent stacking
    messenger.clearSnackBars();

    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 2),
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: topMargin,
          left: 16,
          right: 16,
          bottom: bottomMargin,
        ),
      ),
    );
  }
}
