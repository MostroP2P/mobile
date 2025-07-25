import 'dart:convert';
import 'package:mostro_mobile/data/models/enums/status.dart';
import 'package:mostro_mobile/data/models/range_amount.dart';
import 'package:mostro_mobile/data/models/enums/order_type.dart';
import 'package:mostro_mobile/data/models/rating.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
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
  Status get status => Status.fromString(_getTagValue('s')!);
  String? get amount => _getTagValue('amt');
  RangeAmount get fiatAmount => _getAmount('fa');
  List<String> get paymentMethods {
    final tag = tags?.firstWhere((t) => t[0] == 'pm', orElse: () => []);
    if (tag != null && tag.length > 1) {
      return tag.sublist(1);
    }
    return [];
  }

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
  String? timeAgoWithLocale(String? locale) =>
      _timeAgo(_getTagValue('expiration'), locale);
  DateTime get expirationDate => _getTimeStamp(_getTagValue('expiration')!);
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

  DateTime _getTimeStamp(String timestamp) {
    final ts = int.parse(timestamp);
    return DateTime.fromMillisecondsSinceEpoch(ts * 1000)
        .subtract(Duration(hours: 12));
  }

  String _timeAgo(String? ts, [String? locale]) {
    if (ts == null) return "invalid date";
    final timestamp = int.tryParse(ts);
    if (timestamp != null && timestamp > 0) {
      final DateTime eventTime =
          DateTime.fromMillisecondsSinceEpoch(timestamp * 1000)
              .subtract(Duration(hours: 48));

      // Use provided locale or fallback to Spanish
      final effectiveLocale = locale ?? 'es';
      return timeago.format(eventTime,
          allowFromNow: true, locale: effectiveLocale);
    } else {
      return "invalid date";
    }
  }

  Future<NostrEvent> unWrap(String privateKey) async {
    return await NostrUtils.decryptNIP59Event(
      this,
      privateKey,
    );
  }

  Future<NostrEvent> mostroUnWrap(NostrKeyPairs receiver) async {
    if (kind != 1059) {
      throw ArgumentError('Wrong kind: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Event content is empty');
    }

    final decryptedContent = await NostrUtils.decryptNIP44(
      content!,
      receiver.private,
      pubkey,
    );

    final rumorEvent = NostrEvent.deserialized(
      '["EVENT", "", $decryptedContent]',
    );
    if (rumorEvent.kind != 1) {
      throw Exception('Not a Mostro DM: ${rumorEvent.toString()}');
    }
    return rumorEvent;
  }

  Future<NostrEvent> mostroWrap(NostrKeyPairs sharedKey) async {
    if (kind != 1) {
      throw ArgumentError('Wrong kind: $kind');
    }

    if (content == null || content!.isEmpty) {
      throw ArgumentError('Event content is empty');
    }

    final wrapperKeyPair = NostrUtils.generateKeyPair();

    final encryptedContent = await NostrUtils.encryptNIP44(
      jsonEncode(toMap()),
      wrapperKeyPair.private,
      sharedKey.public,
    );

    final event = NostrUtils.createWrap(
      wrapperKeyPair,
      encryptedContent,
      sharedKey.public,
    );
    return event;
  }

  NostrEvent copy() {
    return NostrEvent(
      content: content,
      createdAt: createdAt,
      id: id,
      kind: kind,
      pubkey: pubkey,
      sig: sig,
      tags: tags,
    );
  }

  static NostrEvent fromMap(Map<String, dynamic> event) {
    return NostrEvent(
      id: event['id'] as String,
      kind: event['kind'] as int,
      content: event['content'] == null ? '' : event['content'] as String,
      sig: event['sig'] as String,
      pubkey: event['pubkey'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (event['created_at'] as int) * 1000,
      ),
      tags: List<List<String>>.from(
        (event['tags'] as List)
            .map(
              (nestedElem) => (nestedElem as List)
                  .map(
                    (nestedElemContent) => nestedElemContent.toString(),
                  )
                  .toList(),
            )
            .toList(),
      ),
    );
  }
}
