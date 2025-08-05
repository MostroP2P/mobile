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
}