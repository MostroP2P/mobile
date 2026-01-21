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
    // Calculate positioning using system values
    final mediaQuery = MediaQuery.of(context);
    final statusBarHeight = mediaQuery.padding.top; // Real status bar height (varies by device)
    final appBarHeight = kToolbarHeight; // Standard AppBar height (56px)
    final extraMargin = 4.0; // Minimal margin for tighter spacing
    final topMargin = statusBarHeight + appBarHeight + extraMargin;

    final estimatedSnackBarHeight = 60.0; // Estimated height optimized for 1-2 line messages
    final bottomMargin = mediaQuery.size.height - topMargin - estimatedSnackBarHeight;

    // Clear any existing SnackBars to prevent stacking
    ScaffoldMessenger.of(context).clearSnackBars();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
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
