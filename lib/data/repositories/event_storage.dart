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
  
  /// Stream of all events for a query
  Stream<List<NostrEvent>> watchAll({Filter? filter}) {
    final finder = filter != null ? Finder(filter: filter) : null;
    
    return store
      .query(finder: finder)
      .onSnapshots(db)
      .map((snapshots) => snapshots
        .map((snapshot) => fromDbMap(snapshot.key, snapshot.value))
        .toList());
  }
  
  /// Stream of the latest event matching a query
  Stream<NostrEvent?> watchLatest({Filter? filter, List<SortOrder>? sortOrders}) {
    final finder = Finder(
      filter: filter,
      sortOrders: sortOrders ?? [SortOrder('created_at', false)],
      limit: 1
    );
    
    return store
      .query(finder: finder)
      .onSnapshots(db)
      .map((snapshots) => snapshots.isNotEmpty 
        ? fromDbMap(snapshots.first.key, snapshots.first.value)
        : null);
  }
  
  /// Stream of events filtered by event ID
  @override
  Stream<NostrEvent?> watchById(String eventId) {
    final finder = Finder(
      filter: Filter.equals('id', eventId),
      limit: 1
    );
    
    return store
      .query(finder: finder)
      .onSnapshots(db)
      .map((snapshots) => snapshots.isNotEmpty 
        ? fromDbMap(snapshots.first.key, snapshots.first.value)
        : null);
  }
}
