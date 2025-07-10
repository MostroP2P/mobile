import 'package:dart_nostr/dart_nostr.dart';

extension NostrRequestX on NostrRequest {
  static NostrRequest fromJson(List<dynamic> json) {
    final filters = json
        .map(
          (e) => NostrFilterX.fromJsonSafe(e),
        )
        .toList();

    return NostrRequest(
      filters: filters,
    );
  }
}

extension NostrFilterX on NostrFilter {
  static NostrFilter fromJsonSafe(Map<String, dynamic> json) {
    final additional = <String, dynamic>{};

    for (final entry in json.entries) {
      if (![
        'ids',
        'authors',
        'kinds',
        '#e',
        '#p',
        '#t',
        '#a',
        'since',
        'until',
        'limit',
        'search',
      ].contains(entry.key)) {
        additional[entry.key] = entry.value;
      }
    }

    return NostrFilter(
      ids: castList<String>(json['ids']),
      authors: castList<String>(json['authors']),
      kinds: castList<int>(json['kinds']),
      e: castList<String>(json['#e']),
      p: castList<String>(json['#p']),
      t: castList<String>(json['#t']),
      a: castList<String>(json['#a']),
      since: safeCast<int>(json['since']) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              safeCast<int>(json['since'])! * 1000)
          : null,
      until: safeCast<int>(json['until']) != null
          ? DateTime.fromMillisecondsSinceEpoch(
              safeCast<int>(json['until'])! * 1000)
          : null,
      limit: safeCast<int>(json['limit']),
      search: safeCast<String>(json['search']),
      additionalFilters: additional.isEmpty ? null : additional,
    );
  }

  static T? safeCast<T>(dynamic value) {
    if (value is T) return value;
    return null;
  }

  static List<T>? castList<T>(dynamic value) {
    if (value is List) return value.cast<T>();
    return null;
  }
}
