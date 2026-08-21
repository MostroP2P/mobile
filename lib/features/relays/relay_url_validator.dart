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
  /// Octet and port ranges are checked separately in [_isValidLocalHost].
  static final RegExp _localHostRegex =
      RegExp(r'^(localhost|\d{1,3}(\.\d{1,3}){3})(:(\d{1,5}))?$');

  static const int _maxOctet = 255;
  static const int _maxPort = 65535;
  static final RegExp _trailingSlashes = RegExp(r'/+$');

  /// Normalizes [input] into a relay URL, or returns null when rejected.
  ///
  /// - `wss://` is kept as-is.
  /// - `ws://` is kept only when [allowInsecure] is true.
  /// - `http(s)://` is always rejected.
  /// - A bare host gets a `wss://` prefix; it is never silently downgraded
  ///   to `ws://`, the user has to ask for that explicitly.
  String? normalize(String input) {
    final value =
        input.trim().toLowerCase().replaceFirst(_trailingSlashes, '');

    if (!isValidHost(value)) return null;

    if (value.startsWith('wss://')) return value;
    if (value.startsWith('ws://')) return allowInsecure ? value : null;
    if (value.startsWith('http')) return null;
    return 'wss://$value';
  }

  /// Whether the host part of [input] (protocol prefix optional) is acceptable.
  bool isValidHost(String input) {
    final host = _stripProtocol(input);

    if (allowInsecure && _isValidLocalHost(host)) return true;

    // Reject IP addresses (numbers and dots only).
    if (RegExp(r'^[\d.]+$').hasMatch(host)) return false;

    return _domainRegex.hasMatch(host) && host.contains('.');
  }

  /// `localhost` or IPv4 with octets in 0-255 and, if given, a port in
  /// 1-65535.
  static bool _isValidLocalHost(String host) {
    final match = _localHostRegex.firstMatch(host);
    if (match == null) return false;

    final name = match.group(1)!;
    if (name != 'localhost') {
      final octetsInRange = name
          .split('.')
          .every((octet) => int.parse(octet) <= _maxOctet);
      if (!octetsInRange) return false;
    }

    final port = match.group(4);
    if (port == null) return true;
    final portNumber = int.parse(port);
    return portNumber >= 1 && portNumber <= _maxPort;
  }

  static String _stripProtocol(String input) {
    for (final prefix in const ['wss://', 'ws://', 'https://', 'http://']) {
      if (input.startsWith(prefix)) return input.substring(prefix.length);
    }
    return input;
  }
}
