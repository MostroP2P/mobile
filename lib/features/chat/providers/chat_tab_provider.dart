import 'package:flutter_riverpod/flutter_riverpod.dart';

enum ChatTabType { messages, disputes }

final chatTabProvider = StateProvider((ref) => ChatTabType.messages);
