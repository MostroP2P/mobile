import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/test_environment.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';

/// Matches every trailing slash so `wss://relay.example//` normalizes the same
/// way as `wss://relay.example/`.
final RegExp _trailingSlashes = RegExp(r'/+$');

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

  /// Upper bound on the relays one event may contribute.
  ///
  /// A node's NIP-65 list is a handful of entries. The number is a sanity
  /// bound on an attacker-controlled list, not a policy: without one, a single
  /// event can name as many relays as it likes and every one of them joins the
  /// active set and receives every subscription.
  static const int maxRelays = 50;

  /// Parses a kind 10002 Nostr event into a RelayListEvent.
  ///
  /// Returns null unless the event is a kind-10002 event that the author it
  /// claims actually signed. This is the only way a [RelayListEvent] is
  /// produced, so the check lives here rather than at each call site: what the
  /// list names becomes the app's relay set, which is the position every other
  /// relay-sourced attack is launched from. The author field on its own is a
  /// relay's claim about an event it chose to hand over.
  ///
  /// Verifying here also makes [publishedAt] mean something: the freshness
  /// comparison downstream is against `created_at`, which is covered by the
  /// signature and the recomputed id, so a relay cannot backdate or
  /// future-date a list to control which one wins.
  static RelayListEvent? fromEvent(NostrEvent event) {
    if (event.kind != 10002) return null;

    if (!NostrUtils.isValidEventSignature(event)) {
      logger.w(
        'Rejecting kind-10002 relay list claiming to be from ${event.pubkey}: '
        'signature verification failed',
      );
      return null;
    }

    // Extract relay URLs from 'r' tags
    var relays = event.tags
        ?.where((tag) => tag.isNotEmpty && tag[0] == 'r')
        .where((tag) => tag.length >= 2)
        .map((tag) => tag[1])
        .where((url) => url.isNotEmpty)
        .toList() ?? <String>[];

    if (relays.length > maxRelays) {
      logger.w(
        'Relay list from ${event.pubkey} names ${relays.length} relays; '
        'keeping the first $maxRelays',
      );
      relays = relays.sublist(0, maxRelays);
    }

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
  ///
  /// Cleartext `ws://` is refused on the same terms as the manual-entry path:
  /// only inside the Mortsom test environment, where the relay is a local
  /// process on a private address. Accepting it here was a way around that
  /// rule — a node's list could downgrade the app's transport to plaintext
  /// without the user ever typing a URL.
  List<String> get validRelays {
    return relays
        .where((url) =>
            url.startsWith('wss://') ||
            (TestEnvironment.allowInsecureRelays && url.startsWith('ws://')))
        .map((url) => url.trim())
        .map((url) => url.replaceAll(_trailingSlashes, ''))
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