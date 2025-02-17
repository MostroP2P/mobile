import 'package:dart_nostr/nostr/model/event/event.dart';

class Messages {
  final String buyerPubkey;
  final String sellerPubkey;
  final List<NostrEvent> messages = [];

  Messages({required this.buyerPubkey, required this.sellerPubkey});

  void sortMessages() {
    messages.sort((a, b) => a.createdAt!.compareTo(b.createdAt!));
  }
}
