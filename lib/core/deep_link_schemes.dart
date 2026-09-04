/// Whether the URI uses a scheme the app resolves itself, such as `mostro:`
bool isCustomSchemeUri(Uri uri) =>
    uri.scheme.isNotEmpty && uri.scheme != 'http' && uri.scheme != 'https';

/// [isCustomSchemeUri] for an unparsed location; unparseable input is
/// treated as not custom.
bool isCustomSchemeLocation(String location) {
  final uri = Uri.tryParse(location);
  return uri != null && isCustomSchemeUri(uri);
}
