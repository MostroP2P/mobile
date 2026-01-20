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
    // Calculate bottom margin to force SnackBar to appear at top
    final mediaQuery = MediaQuery.of(context);
    final bottomMargin = mediaQuery.size.height - 96 - 70; // screen height - top margin - snackbar height (~70px)

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        backgroundColor: backgroundColor,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          top: 96,  // Status bar (24px) + AppBar (56px) + margin (16px) = 96px optimized for Android
          left: 16,
          right: 16,
          bottom: bottomMargin, // Force positioning at top by setting large bottom margin
        ),
      ),
    );
  }
}
