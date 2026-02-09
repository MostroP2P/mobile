import 'package:flutter_test/flutter_test.dart';
import 'package:mostro_mobile/features/mostro/mostro_node.dart';

void main() {
  group('MostroNode', () {
    test('serialization round-trip preserves all fields', () {
      final node = MostroNode(
        pubkey:
            'abc123def456abc123def456abc123def456abc123def456abc123def456abcd',
        name: 'Test Node',
        picture: 'https://example.com/pic.png',
        website: 'https://example.com',
        about: 'A test node',
        isTrusted: true,
        addedAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      final json = node.toJson();
      final restored = MostroNode.fromJson(json);

      expect(restored.pubkey, node.pubkey);
      expect(restored.name, node.name);
      expect(restored.picture, node.picture);
      expect(restored.website, node.website);
      expect(restored.about, node.about);
      expect(restored.isTrusted, node.isTrusted);
      expect(restored.addedAt, node.addedAt);
    });

    test('fromJson handles missing optional fields', () {
      final json = {'pubkey': 'abc123def456abc123def456'};
      final node = MostroNode.fromJson(json);

      expect(node.pubkey, 'abc123def456abc123def456');
      expect(node.name, isNull);
      expect(node.picture, isNull);
      expect(node.website, isNull);
      expect(node.about, isNull);
      expect(node.isTrusted, false);
      expect(node.addedAt, isNull);
    });

    test('displayName returns name when available', () {
      final node = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'My Node',
      );
      expect(node.displayName, 'My Node');
    });

    test('displayName returns truncated pubkey when no name', () {
      final node = MostroNode(pubkey: 'abcde12345fghij67890');
      expect(node.displayName, 'abcde...67890');
    });

    test('truncatedPubkey format', () {
      final node = MostroNode(pubkey: 'abcde12345fghij67890');
      expect(node.truncatedPubkey, 'abcde...67890');
    });

    test('truncatedPubkey returns full pubkey when too short', () {
      final node = MostroNode(pubkey: 'short');
      expect(node.truncatedPubkey, 'short');
    });

    test('truncatedPubkey handles exactly 10 char pubkey', () {
      final node = MostroNode(pubkey: '1234567890');
      expect(node.truncatedPubkey, '1234567890');
    });

    test('withMetadata creates copy with updated fields', () {
      final original = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'Original',
        isTrusted: true,
      );

      final updated = original.withMetadata(
        name: 'Updated',
        picture: 'https://pic.com',
        about: 'New description',
      );

      expect(updated.pubkey, 'abcde12345fghij67890');
      expect(updated.name, 'Updated');
      expect(updated.picture, 'https://pic.com');
      expect(updated.about, 'New description');
      expect(updated.isTrusted, true);
      expect(original.name, 'Original');
      expect(original.picture, isNull);
    });

    test('withMetadata preserves existing fields when null passed', () {
      final original = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'Name',
        picture: 'https://pic.com',
      );

      final updated = original.withMetadata(about: 'New about');

      expect(updated.name, 'Name');
      expect(updated.picture, 'https://pic.com');
      expect(updated.about, 'New about');
    });

    test('withMetadata clears fields when MostroNode.clear is passed', () {
      final original = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'Name',
        picture: 'https://pic.com',
        website: 'https://site.com',
        about: 'About text',
      );

      final cleared = original.withMetadata(
        name: MostroNode.clear,
        picture: MostroNode.clear,
      );

      expect(cleared.name, isNull);
      expect(cleared.picture, isNull);
      // Uncleared fields preserved
      expect(cleared.website, 'https://site.com');
      expect(cleared.about, 'About text');
    });

    test('equality is based on pubkey', () {
      final node1 = MostroNode(pubkey: 'abcde12345fghij67890', name: 'Node 1');
      final node2 = MostroNode(pubkey: 'abcde12345fghij67890', name: 'Node 2');
      final node3 = MostroNode(pubkey: 'defgh12345fghij67890', name: 'Node 1');

      expect(node1, equals(node2));
      expect(node1, isNot(equals(node3)));
    });

    test('hashCode is based on pubkey', () {
      final node1 = MostroNode(pubkey: 'abcde12345fghij67890');
      final node2 = MostroNode(pubkey: 'abcde12345fghij67890');

      expect(node1.hashCode, node2.hashCode);
    });

    test('toJson includes all fields', () {
      final addedAt = DateTime.fromMillisecondsSinceEpoch(1700000000000);
      final node = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'Test',
        picture: 'https://pic.com',
        website: 'https://site.com',
        about: 'About text',
        isTrusted: false,
        addedAt: addedAt,
      );

      final json = node.toJson();
      expect(json['pubkey'], 'abcde12345fghij67890');
      expect(json['name'], 'Test');
      expect(json['picture'], 'https://pic.com');
      expect(json['website'], 'https://site.com');
      expect(json['about'], 'About text');
      expect(json['isTrusted'], false);
      expect(json['addedAt'], 1700000000000);
    });

    test('toJson handles null optional fields', () {
      final node = MostroNode(pubkey: 'abcde12345fghij67890');

      final json = node.toJson();
      expect(json['pubkey'], 'abcde12345fghij67890');
      expect(json['name'], isNull);
      expect(json['picture'], isNull);
      expect(json['addedAt'], isNull);
      expect(json['isTrusted'], false);
    });

    test('toString contains key info', () {
      final node = MostroNode(
        pubkey: 'abcde12345fghij67890',
        name: 'Test Node',
        isTrusted: true,
      );

      final str = node.toString();
      expect(str, contains('abcde...67890'));
      expect(str, contains('Test Node'));
      expect(str, contains('true'));
    });
  });
}
