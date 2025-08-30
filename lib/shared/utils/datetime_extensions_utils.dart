import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

extension DateTimeExtensions on DateTime {
  String timeAgoWithLocale(BuildContext context, [String? locale]) {
    final effectiveLocale = locale ?? Localizations.localeOf(context).languageCode;
    return timeago.format(this, locale: effectiveLocale);
  }
  
  String timeAgoDefault([String locale = 'en']) {
    return timeago.format(this, locale: locale);
  }

  String preciseTimeAgo(BuildContext context, [String? locale]) {
    final now = DateTime.now();
    final difference = now.difference(this);
    final effectiveLocale = locale ?? Localizations.localeOf(context).languageCode;
    
    if (difference.inSeconds < 60) {
      return effectiveLocale == 'es' 
          ? 'hace ${difference.inSeconds} segundos'
          : effectiveLocale == 'it'
              ? '${difference.inSeconds} secondi fa'
              : '${difference.inSeconds} seconds ago';
    }
    
    return timeago.format(this, locale: effectiveLocale);
  }
}