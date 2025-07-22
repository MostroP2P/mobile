import 'package:mostro_mobile/data/models/payload.dart';

class TextMessage implements Payload {
  final String message;

  TextMessage({required this.message}) {
    if (message.isEmpty) {
      throw ArgumentError('Text message cannot be empty');
    }
  }

  factory TextMessage.fromJson(Map<String, dynamic> json) {
    try {
      final messageValue = json['message'] ?? json['text_message'];
      if (messageValue == null) {
        throw FormatException('Missing required field: message or text_message');
      }
      
      final messageString = messageValue.toString();
      if (messageString.isEmpty) {
        throw FormatException('Text message cannot be empty');
      }
      
      return TextMessage(message: messageString);
    } catch (e) {
      throw FormatException('Failed to parse TextMessage from JSON: $e');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: message,
    };
  }

  @override
  String get type => 'text_message';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextMessage && other.message == message;
  }
  
  @override
  int get hashCode => message.hashCode;
  
  @override
  String toString() => 'TextMessage(message: $message)';
}
