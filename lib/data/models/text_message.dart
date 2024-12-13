import 'package:mostro_mobile/data/models/content.dart';

class TextMessage implements Content {
  final String message;

  TextMessage({required this.message});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: message,
    };
  }

  @override
  String get type => 'text_message';
}
