import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Replace with your SharedPreferencesAsync import if needed

class MemoryTextField extends StatefulWidget {
  /// The label for the text field.
  final String label;
  /// A unique key string for persisting the history of inputs.
  final String historyKey;
  /// An optional callback that fires whenever the text changes.
  final ValueChanged<String>? onChanged;

  const MemoryTextField({
    super.key,
    required this.label,
    required this.historyKey,
    this.onChanged,
  });

  @override
  MemoryTextFieldState createState() => MemoryTextFieldState();
}

class MemoryTextFieldState extends State<MemoryTextField> {
  final TextEditingController _controller = TextEditingController();
  // In-memory list for storing previously entered values.
  List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final historyJson = prefs.getString(widget.historyKey);
    if (historyJson != null) {
      final List<dynamic> list = jsonDecode(historyJson);
      setState(() {
        _history = list.cast<String>();
      });
    }
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(widget.historyKey, jsonEncode(_history));
  }

  void _handleSubmitted(String value) {
    if (value.isNotEmpty && !_history.contains(value)) {
      setState(() {
        _history.add(value);
      });
      _saveHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return const Iterable<String>.empty();
        }
        return _history.where((String option) =>
            option.toLowerCase().contains(textEditingValue.text.toLowerCase()));
      },
      onSelected: (String selection) {
        _controller.text = selection;
        if (widget.onChanged != null) {
          widget.onChanged!(selection);
        }
      },
      fieldViewBuilder: (BuildContext context,
          TextEditingController fieldTextEditingController,
          FocusNode fieldFocusNode,
          VoidCallback onFieldSubmitted) {
        // Synchronize the controller values.
        _controller.value = fieldTextEditingController.value;
        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          decoration: InputDecoration(
            labelText: widget.label,
          ),
          onChanged: widget.onChanged,
          onFieldSubmitted: (value) {
            _handleSubmitted(value);
            onFieldSubmitted();
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
