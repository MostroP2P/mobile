import 'package:mostro_mobile/data/models/payload.dart';

class TextMessage implements Payload {
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
