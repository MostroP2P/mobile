import 'package:flutter_riverpod/legacy.dart';

enum ChatTabType { messages, disputes }

final chatTabProvider = StateProvider<ChatTabType>((ref) => ChatTabType.messages);
