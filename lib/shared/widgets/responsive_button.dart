import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ButtonStyleType { raised, outlined }

class ResponsiveButton<T> extends ConsumerStatefulWidget {
  final String label;
  final ButtonStyleType buttonStyle;
  final VoidCallback onPressed;
  final AsyncNotifierProvider<AsyncNotifier<AsyncValue<T>>, AsyncValue<T>>
      listenTo;
  final Duration timeout;
  final String errorSnackbarMessage;

  const ResponsiveButton({
    super.key,
    required this.label,
    required this.buttonStyle,
    required this.onPressed,
    required this.listenTo,
    this.timeout = const Duration(seconds: 5),
    this.errorSnackbarMessage = 'Something went wrong.',
  });

  @override
  ConsumerState<ResponsiveButton> createState() => _ResponsiveButtonState<T>();
}

class _ResponsiveButtonState<T> extends ConsumerState<ResponsiveButton<T>> {
  bool _loading = false;
  late final VoidCallback _listener;

  @override
  void initState() {
    super.initState();
    _listener = () {
      final state = ref.read(widget.listenTo);
      if (_loading) {
        if (state is AsyncData<T>) {
          setState(() => _loading = false);
        } else if (state is AsyncError) {
          _showError();
        }
      }
    };
  }

  void _showError() {
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.errorSnackbarMessage)),
      );
    }
  }

  Future<void> _handlePress() async {
    setState(() => _loading = true);
    widget.onPressed();

    // Start timeout countdown
    Future.delayed(widget.timeout, () {
      final state = ref.read(widget.listenTo);
      if (_loading && state is! AsyncData<T>) {
        _showError();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(widget.listenTo, (_, __) => _listener());

    final child = _loading
        ? const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(widget.label);

    final button = switch (widget.buttonStyle) {
      ButtonStyleType.raised => ElevatedButton(
          onPressed: _loading ? null : _handlePress,
          child: child,
        ),
      ButtonStyleType.outlined => OutlinedButton(
          onPressed: _loading ? null : _handlePress,
          child: child,
        ),
    };

    return SizedBox(height: 48, child: button);
  }
}
