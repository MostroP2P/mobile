import 'package:mostro_mobile/data/models/range_amount.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/rating.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:dart_nostr/dart_nostr.dart';

extension NostrEventExtensions on NostrEvent {
  // Getters para acceder fácilmente a los tags específicos
  String? get recipient => _getTagValue('p');
  String? get orderId => _getTagValue('d');
  OrderType? get orderType => _getTagValue('k') != null
      ? OrderType.fromString(_getTagValue('k')!)
      : null;
  String? get currency => _getTagValue('f');
  String? get status => _getTagValue('s');
  String? get amount => _getTagValue('amt');
  RangeAmount get fiatAmount => _getAmount('fa');
  List<String> get paymentMethods => _getTagValue('pm')?.split(',') ?? [];
  String? get premium => _getTagValue('premium');
  String? get source => _getTagValue('source');
  Rating? get rating => _getTagValue('rating') != null
      ? Rating.deserialized(_getTagValue('rating')!)
      : null;
  String? get network => _getTagValue('network');
  String? get layer => _getTagValue('layer');
  String? get name => _getTagValue('name') ?? 'Anon';
  String? get geohash => _getTagValue('g');
  String? get bond => _getTagValue('bond');
  String? get expiration => _timeAgo(_getTagValue('expiration'));
  String? get platform => _getTagValue('y');
  String get type => _getTagValue('z')!;

  String? _getTagValue(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1) ? tag[1] : null;
  }

  RangeAmount _getAmount(String key) {
    final tag = tags?.firstWhere((t) => t[0] == key, orElse: () => []);
    return (tag != null && tag.length > 1)
        ? RangeAmount.fromList(tag)
        : RangeAmount.empty();
  }

  String _timeAgo(String? ts) {
    if (ts == null) return "invalid date";
    final timestamp = int.tryParse(ts);
    if (timestamp != null && timestamp > 0) {
      final DateTime eventTime =
          DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
              .subtract(Duration(hours: 36));
      return timeago.format(eventTime, allowFromNow: true);
    } else {
      return "invalid date";
    }
  }
}
