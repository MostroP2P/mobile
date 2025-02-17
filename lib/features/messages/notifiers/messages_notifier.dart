import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models/messages.dart';

class MessagesNotifier extends StateNotifier<Messages> {
  MessagesNotifier(super.state);


  Future<void> subscribe(Stream<NostrEvent> stream) async {
  }


}