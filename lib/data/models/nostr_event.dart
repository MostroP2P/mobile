import 'dart:convert';
import 'package:mostro_mobile/core/utils/nostr_utils.dart';
import 'package:pointycastle/export.dart' as pc; // Alias para pointycastle

class NostrEvent {
  String id;
  int kind;
  String pubkey;
  String content;
  DateTime createdAt;
  List<List<String>>? tags;
  String sig;

  NostrEvent({
    required this.id,
    required this.kind,
    required this.pubkey,
    required this.content,
    required this.createdAt,
    this.tags,
    required this.sig,
  });

  // Método para generar el ID del evento
  String generateId() {
    final eventContent = {
      'kind': kind,
      'pubkey': pubkey,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'tags': tags ?? [],
    };

    return NostrUtils.generateId(eventContent);
  }

  // Método para firmar el evento usando la clave privada
  String signEvent(pc.ECPrivateKey privateKey) {
    final eventContent = {
      'kind': kind,
      'pubkey': pubkey,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch ~/ 1000,
      'tags': tags ?? [],
    };

    return NostrUtils.signMessage(jsonEncode(eventContent), privateKey);
  }
}
