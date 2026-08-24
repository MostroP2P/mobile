/// Why a user-entered relay URL was rejected by [RelayUrlValidator].
enum RelayUrlRejection {
  /// Plain `ws://` is not allowed in this build, or it targets a non-local
  /// host (plain text is only ever accepted towards `localhost` or a private
  /// IPv4 address).
  insecureScheme,

  /// `http://` / `https://` are never relay URLs.
  httpScheme,

  /// The host (or port) is malformed or not allowed in this build.
  invalidHost,
}

/// Outcome of [RelayUrlValidator.validate]: exactly one of [url] or
/// [rejection] is set.
class RelayUrlValidation {
  const RelayUrlValidation.accepted(String this.url) : rejection = null;
  const RelayUrlValidation.rejected(RelayUrlRejection this.rejection)
      : url = null;

  final String? url;
  final RelayUrlRejection? rejection;

  bool get isAccepted => url != null;
}

/// Pure validation and normalization of user-entered relay URLs.
///
/// Kept free of Riverpod/Nostr dependencies so it can be unit-tested directly.
///
/// Policy:
/// - `wss://` (or a bare host, which gets `wss://` prepended) to a public
///   domain name is always accepted. An optional `:port` is allowed.
/// - With [allowInsecure], local hosts (`localhost` or a private IPv4 address
///   as defined in [_isPrivateIPv4], optional `:port`) are accepted too, and
///   plain `ws://` is accepted **only** towards those local hosts. Neither a
///   public IPv4 address nor plain text to a public relay is ever accepted.
/// - `http(s)://` is always rejected.
///
/// Callers decide when [allowInsecure] is acceptable: see
/// `Config.allowInsecureRelays`.
class RelayUrlValidator {
  const RelayUrlValidator({required this.allowInsecure});

  final bool allowInsecure;

  static const int _maxOctet = 255;
  static const int _maxPort = 65535;

  static final RegExp _trailingSlashes = RegExp(r'/+$');

  /// A domain name (at least one dot enforced separately) with an optional
  /// `:port`. The port range is checked in [_isValidPort].
  static final RegExp _domainRegex = RegExp(
      r'^(?<host>[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*)'
      r'(?::(?<port>\d{1,5}))?$');

  /// `localhost` or a dotted IPv4 address with an optional `:port`. Octet
  /// ranges, the private-address requirement and the port range are checked
  /// in [_isValidLocalHost].
  static final RegExp _localHostRegex = RegExp(
      r'^(?<host>localhost|\d{1,3}(\.\d{1,3}){3})(?::(?<port>\d{1,5}))?$');

  /// Numbers and dots only: an IP-looking host that is not a valid local host.
  static final RegExp _bareIpRegex = RegExp(r'^[\d.]+$');

  /// Canonical comparison key for a relay URL, shared by every place that
  /// dedupes or blacklists relays: trimmed, trailing slashes removed, scheme
  /// and host lowercased (a path, if any, keeps its case).
  static String canonicalKey(String url) {
    final trimmed = url.trim().replaceFirst(_trailingSlashes, '');
    final schemeEnd = trimmed.indexOf('://');
    final hostStart = schemeEnd == -1 ? 0 : schemeEnd + 3;
    final pathStart = trimmed.indexOf('/', hostStart);
    if (pathStart == -1) return trimmed.toLowerCase();
    return trimmed.substring(0, pathStart).toLowerCase() +
        trimmed.substring(pathStart);
  }

  /// Normalizes [input] into a relay URL, or returns null when rejected.
  /// Use [validate] when the rejection reason matters.
  String? normalize(String input) => validate(input).url;

  /// Validates [input] and returns either the normalized URL or the reason
  /// it was rejected.
  RelayUrlValidation validate(String input) {
    final value = canonicalKey(input);

    final schemeEnd = value.indexOf('://');
    final scheme = schemeEnd == -1 ? null : value.substring(0, schemeEnd);
    final host = schemeEnd == -1 ? value : value.substring(schemeEnd + 3);

    switch (scheme) {
      case null:
      case 'wss':
        if (!_isValidHost(host)) {
          return const RelayUrlValidation.rejected(
              RelayUrlRejection.invalidHost);
        }
        return RelayUrlValidation.accepted('wss://$host');
      case 'ws':
        // Plain text only ever towards a local host, and only when allowed.
        if (!allowInsecure) {
          return const RelayUrlValidation.rejected(
              RelayUrlRejection.insecureScheme);
        }
        if (_isValidLocalHost(host)) {
          return RelayUrlValidation.accepted('ws://$host');
        }
        // Allowed build but not a valid local host: either a well-formed
        // public host (plain text refused) or a malformed host/port, which
        // must not be reported as a scheme problem.
        return RelayUrlValidation.rejected(_isValidHost(host)
            ? RelayUrlRejection.insecureScheme
            : RelayUrlRejection.invalidHost);
      case 'http':
      case 'https':
        return const RelayUrlValidation.rejected(RelayUrlRejection.httpScheme);
      default:
        return const RelayUrlValidation.rejected(RelayUrlRejection.invalidHost);
    }
  }

  /// Whether [host] (no scheme, already lowercased, optional `:port`) is an
  /// acceptable relay host in this build.
  bool _isValidHost(String host) {
    if (allowInsecure && _isValidLocalHost(host)) return true;
    if (_bareIpRegex.hasMatch(host.split(':').first)) return false;

    final match = _domainRegex.firstMatch(host);
    if (match == null) return false;
    return match.namedGroup('host')!.contains('.') &&
        _isValidPort(match.namedGroup('port'));
  }

  /// `localhost` or a private IPv4 address with octets in 0-255 and, if
  /// given, a port in 1-65535. A public IPv4 address is not a local host: it
  /// must not be reachable over plain text just because the build allows
  /// insecure relays.
  static bool _isValidLocalHost(String host) {
    final match = _localHostRegex.firstMatch(host);
    if (match == null) return false;

    final name = match.namedGroup('host')!;
    if (name != 'localhost') {
      final octets = name.split('.').map(int.parse).toList();
      if (octets.any((octet) => octet > _maxOctet)) return false;
      if (!_isPrivateIPv4(octets)) return false;
    }
    return _isValidPort(match.namedGroup('port'));
  }

  /// Loopback and the RFC 1918 private ranges: 127.0.0.0/8, 10.0.0.0/8,
  /// 172.16.0.0/12 and 192.168.0.0/16. Covers `10.0.2.2` (the Android
  /// emulator's host) and a LAN address when testing on a physical device.
  static bool _isPrivateIPv4(List<int> octets) =>
      octets[0] == 127 ||
      octets[0] == 10 ||
      (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
      (octets[0] == 192 && octets[1] == 168);

  static bool _isValidPort(String? port) {
    if (port == null) return true;
    final portNumber = int.parse(port);
    return portNumber >= 1 && portNumber <= _maxPort;
  }
}
