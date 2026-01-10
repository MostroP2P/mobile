import 'package:flutter/material.dart';

void showTopSnackBar(
  BuildContext context,
  String message, {
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  final messenger = ScaffoldMessenger.of(context);

  // Remove any existing SnackBars
  messenger.clearSnackBars();

  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      duration: duration,
      backgroundColor: backgroundColor,
      margin: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
      ),
    ),
  );
}
