import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

enum ButtonStyleType { raised, outlined, text }

/// A button specially designed for Nostr operations that shows loading state
/// and handles the unique event-based nature of Nostr protocols.
class NostrResponsiveButton extends ConsumerStatefulWidget {
  /// Button text
  final String label;
  
  /// Button style type
  final ButtonStyleType buttonStyle;
  
  /// The operation to perform when the button is pressed
  final VoidCallback onPressed;
  
  /// A provider that tracks the state of the operation - should emit a value when operation completes
  final StateProvider<bool> completionProvider;
  
  /// A provider that tracks if there was an error
  final StateProvider<String?> errorProvider;
  
  /// Optional callback when operation completes successfully
  final VoidCallback? onOperationComplete;
  
  /// Optional callback when the operation fails
  final Function(String error)? onOperationError;
  
  /// How long to wait before timing out
  final Duration timeout;
  
  /// Default error message to show
  final String defaultErrorMessage;
  
  /// Width of the button, if null it uses the parent's constraints
  final double? width;
  
  /// Height of the button, defaults to 48
  final double height;
  
  final bool showSuccessIndicator;

  const NostrResponsiveButton({
    super.key,
    required this.label,
    required this.buttonStyle,
    required this.onPressed,
    required this.completionProvider,
    required this.errorProvider,
    this.onOperationComplete,
    this.onOperationError,
    this.timeout = const Duration(seconds: 30), // Nostr operations can take longer
    this.defaultErrorMessage = 'Operation failed. Please try again.',
    this.width,
    this.height = 48,
    this.showSuccessIndicator = false,
  });

  @override
  ConsumerState<NostrResponsiveButton> createState() => _NostrResponsiveButtonState();
}

class _NostrResponsiveButtonState extends ConsumerState<NostrResponsiveButton> {
  bool _loading = false;
  bool _showSuccess = false;
  final _logger = Logger();
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  void _startOperation() {
    setState(() {
      _loading = true;
      _showSuccess = false;
    });
    
    // Reset state providers
    ref.read(widget.completionProvider.notifier).state = false;
    ref.read(widget.errorProvider.notifier).state = null;
    
    // Start the operation
    widget.onPressed();
    
    // Start timeout timer
    _timeoutTimer = Timer(widget.timeout, _handleTimeout);
  }
  
  void _handleTimeout() {
    if (_loading) {
      _logger.w('Operation timed out after ${widget.timeout.inSeconds} seconds');
      setState(() {
        _loading = false;
      });
      
      final errorMsg = 'Operation timed out. Please try again.';
      ref.read(widget.errorProvider.notifier).state = errorMsg;
      
      if (widget.onOperationError != null) {
        widget.onOperationError!(errorMsg);
      } else {
        _showErrorSnackbar(errorMsg);
      }
    }
  }
  
  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }
  
  void _handleCompletion() {
    _timeoutTimer?.cancel();
    
    setState(() {
      _loading = false;
      if (widget.showSuccessIndicator) {
        _showSuccess = true;
        // Reset success indicator after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _showSuccess = false;
            });
          }
        });
      }
    });
    
    if (widget.onOperationComplete != null) {
      widget.onOperationComplete!();
    }
  }
  
  void _handleError(String error) {
    _timeoutTimer?.cancel();
    
    setState(() {
      _loading = false;
    });
    
    if (widget.onOperationError != null) {
      widget.onOperationError!(error);
    } else {
      _showErrorSnackbar(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen to completion
    final isComplete = ref.watch(widget.completionProvider);
    if (isComplete && _loading) {
      _handleCompletion();
    }
    
    // Listen to errors
    final error = ref.watch(widget.errorProvider);
    if (error != null && _loading) {
      _handleError(error);
    }

    Widget childWidget;
    if (_loading) {
      childWidget = const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (_showSuccess) {
      childWidget = const Icon(Icons.check_circle, color: Colors.green);
    } else {
      childWidget = Text(widget.label);
    }

    Widget button;
    switch (widget.buttonStyle) {
      case ButtonStyleType.raised:
        button = ElevatedButton(
          onPressed: _loading ? null : _startOperation,
          child: childWidget,
        );
        break;
      case ButtonStyleType.outlined:
        button = OutlinedButton(
          onPressed: _loading ? null : _startOperation,
          child: childWidget,
        );
        break;
      case ButtonStyleType.text:
        button = TextButton(
          onPressed: _loading ? null : _startOperation,
          child: childWidget,
        );
        break;
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: button,
    );
  }
}
