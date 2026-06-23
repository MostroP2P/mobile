import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatTabType { messages, disputes }

final chatTabProvider = StateProvider<ChatTabType>((ref) => ChatTabType.messages);
