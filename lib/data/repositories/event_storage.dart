import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/data/repositories/base_storage.dart';
import 'package:sembast/sembast.dart';

class EventStorage extends BaseStorage<NostrEvent> {
  EventStorage({
    required Database db,
  }) : super(
          db,
          stringMapStoreFactory.store('events'),
        );

  @override
  NostrEvent fromDbMap(String key, Map<String, dynamic> event) {
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

  @override
  Map<String, dynamic> toDbMap(NostrEvent event) {
    return event.toMap();
  }
}
