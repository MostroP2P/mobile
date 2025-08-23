import 'package:dart_nostr/dart_nostr.dart';

/// Represents a NIP-65 relay list event (kind 10002) from a Mostro instance.
/// These events contain the list of relays where the Mostro instance publishes its events.
class RelayListEvent {
  final List<String> relays;
  final DateTime publishedAt;
  final String authorPubkey;

  const RelayListEvent({
    required this.relays,
    required this.publishedAt,
    required this.authorPubkey,
  });

  /// Parses a kind 10002 Nostr event into a RelayListEvent.
  /// Returns null if the event is not a valid kind 10002 event.
  static RelayListEvent? fromEvent(NostrEvent event) {
    if (event.kind != 10002) return null;

    // Extract relay URLs from 'r' tags
    final relays = event.tags
        ?.where((tag) => tag.isNotEmpty && tag[0] == 'r')
        .where((tag) => tag.length >= 2)
        .map((tag) => tag[1])
        .where((url) => url.isNotEmpty)
        .toList() ?? <String>[];

    // Handle different possible types for createdAt
    DateTime publishedAt;
    if (event.createdAt is DateTime) {
      publishedAt = event.createdAt as DateTime;
    } else if (event.createdAt is int) {
      publishedAt = DateTime.fromMillisecondsSinceEpoch((event.createdAt as int) * 1000);
    } else {
      publishedAt = DateTime.now(); // Fallback to current time
    }

    return RelayListEvent(
      relays: relays,
      publishedAt: publishedAt,
      authorPubkey: event.pubkey,
    );
  }

  /// Validates that all relay URLs are properly formatted WebSocket URLs
  /// Also normalizes URLs by removing trailing slashes to prevent duplicates
  List<String> get validRelays {
    return relays
        .where((url) => url.startsWith('wss://') || url.startsWith('ws://'))
        .map((url) => url.trim())
        .map((url) => url.endsWith('/') ? url.substring(0, url.length - 1) : url)
        .toList();
  }

  @override
  String toString() {
    return 'RelayListEvent(relays: $relays, publishedAt: $publishedAt, author: $authorPubkey)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! RelayListEvent) return false;
    final a = relays.toSet();
    final b = other.relays.toSet();
    return other.authorPubkey == authorPubkey &&
        a.length == b.length &&
        a.containsAll(b);
  }

  @override
  int get hashCode => Object.hash(
        authorPubkey,
        Object.hashAllUnordered(relays.toSet()),
      );
}