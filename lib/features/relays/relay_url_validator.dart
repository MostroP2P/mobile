/// Pure validation and normalization of user-entered relay URLs.
///
/// Kept free of Riverpod/Nostr dependencies so it can be unit-tested directly.
/// [allowInsecure] enables plain `ws://` relays and local hosts (`localhost`,
/// IPv4 addresses, optional port). Callers decide when that is acceptable:
/// see `TestEnvironment.allowInsecureRelays`.
class RelayUrlValidator {
  const RelayUrlValidator({required this.allowInsecure});

  final bool allowInsecure;

  static final RegExp _domainRegex = RegExp(
      r'^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$');

  /// `localhost` or a dotted IPv4 address, with an optional `:port`.
  static final RegExp _localHostRegex =
      RegExp(r'^(localhost|\d{1,3}(\.\d{1,3}){3})(:\d{1,5})?$');

  /// Normalizes [input] into a relay URL, or returns null when rejected.
  ///
  /// - `wss://` is kept as-is.
  /// - `ws://` is kept only when [allowInsecure] is true.
  /// - `http(s)://` is always rejected.
  /// - A bare host gets a `wss://` prefix; it is never silently downgraded
  ///   to `ws://`, the user has to ask for that explicitly.
  String? normalize(String input) {
    final value = input.trim().toLowerCase();

    if (!isValidHost(value)) return null;

    if (value.startsWith('wss://')) return value;
    if (value.startsWith('ws://')) return allowInsecure ? value : null;
    if (value.startsWith('http')) return null;
    return 'wss://$value';
  }

  /// Whether the host part of [input] (protocol prefix optional) is acceptable.
  bool isValidHost(String input) {
    final host = _stripProtocol(input);

    if (allowInsecure && _localHostRegex.hasMatch(host)) return true;

    // Reject IP addresses (numbers and dots only).
    if (RegExp(r'^[\d.]+$').hasMatch(host)) return false;

    return _domainRegex.hasMatch(host) && host.contains('.');
  }

  static String _stripProtocol(String input) {
    for (final prefix in const ['wss://', 'ws://', 'https://', 'http://']) {
      if (input.startsWith(prefix)) return input.substring(prefix.length);
    }
    return input;
  }
}
