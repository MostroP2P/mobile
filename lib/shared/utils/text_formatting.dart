import 'package:flutter/material.dart';

/// Utility function to format text with bold usernames
/// This function specifically looks for known username patterns and makes them bold
TextSpan formatTextWithBoldUsernames(String text, BuildContext context) {
  final style = Theme.of(context).textTheme.bodyLarge;
  
  // Regular expression to match username patterns like "anonymous-finney", "cyber-prague", etc.
  final usernameRegex = RegExp(r'\b[a-z]+-[a-z]+\b');
  
  final spans = <TextSpan>[];
  int lastIndex = 0;
  
  for (final match in usernameRegex.allMatches(text)) {
    // Add text before the username
    if (match.start > lastIndex) {
      spans.add(TextSpan(
        text: text.substring(lastIndex, match.start),
        style: style,
      ));
    }
    
    // Add the username in bold
    spans.add(TextSpan(
      text: match.group(0),
      style: style?.copyWith(fontWeight: FontWeight.bold),
    ));
    
    lastIndex = match.end;
  }
  
  // Add remaining text after the last username
  if (lastIndex < text.length) {
    spans.add(TextSpan(
      text: text.substring(lastIndex),
      style: style,
    ));
  }
  
  // If no usernames found, return the original text
  if (spans.isEmpty) {
    return TextSpan(text: text, style: style);
  }
  
  return TextSpan(children: spans);
}