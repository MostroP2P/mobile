import 'dart:convert';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:mostro_mobile/core/utils/nostr_utils.dart';

class P2POrderEvent {
  String id;
  final String pubkey;
  final int createdAt;
  final int kind = 38383; // Evento P2P con tipo 38383
  final List<List<String>> tags;
  final String content;
  String sig;

  P2POrderEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.tags,
    required this.content,
    required this.sig,
  });

  // Getters para acceder fácilmente a los tags específicos
  String? get orderId => _getTagValue('d');
  String? get orderType => _getTagValue('k');
  String? get currency => _getTagValue('f');
  String? get status => _getTagValue('s');
  String? get amount => _getTagValue('amt');
  String? get fiatAmount => _getTagValue('fa');
  List<String> get paymentMethods => _getTagValue('pm')?.split(',') ?? [];
  String? get premium => _getTagValue('premium');
  String? get network => _getTagValue('network');
  String? get layer => _getTagValue('layer');
  String? get expiration => _getTagValue('expiration');
  String? get platform => _getTagValue('y');

  String? _getTagValue(String key) {
    final tag = tags.firstWhere((t) => t[0] == key, orElse: () => []);
    return tag.length > 1 ? tag[1] : null;
  }

  // Convertir el evento a un mapa JSON
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "pubkey": pubkey,
      "created_at": createdAt,
      "kind": kind,
      "tags": tags,
      "content": content,
      "sig": sig,
    };
  }

  // Convertir el evento a una cadena JSON
  String toJsonString() => jsonEncode(toJson());

  // Factory para crear un evento a partir de un JSON
  factory P2POrderEvent.fromJson(Map<String, dynamic> json) {
    return P2POrderEvent(
      id: json['id'],
      pubkey: json['pubkey'],
      createdAt: json['created_at'],
      tags: List<List<String>>.from(
          json['tags'].map((tag) => List<String>.from(tag))),
      content: json['content'],
      sig: json['sig'],
    );
  }

  // Método para añadir o actualizar un tag
  void setTag(String key, String value) {
    final index = tags.indexWhere((t) => t[0] == key);
    if (index != -1) {
      tags[index] = [key, value];
    } else {
      tags.add([key, value]);
    }
  }

  // Método para validar el evento
  bool isValid() {
    // Implementa la lógica de validación aquí
    // Por ejemplo, verifica que todos los tags obligatorios estén presentes
    return orderId != null &&
        orderType != null &&
        currency != null &&
        status != null;
  }

  // Método para firmar el evento
  void sign(String privateKey) {
    final eventData = {
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
    };

    id = NostrUtils.generateId(eventData);
    sig = Nostr.instance.keysService.sign(privateKey: privateKey, message: id);
  }

  // Método para verificar la firma del evento
  bool verifySignature() {
    final eventData = {
      'pubkey': pubkey,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
    };
    final calculatedId = NostrUtils.generateId(eventData);

    if (calculatedId != id) {
      return false;
    }

    return Nostr.instance.keysService.verify(
      publicKey: pubkey,
      message: id,
      signature: sig,
    );
  }

  // Factory para crear y firmar un nuevo evento
  factory P2POrderEvent.create({
    required String privateKey,
    required int createdAt,
    required List<List<String>> tags,
    required String content,
  }) {
    final keyPair = Nostr.instance.keysService
        .generateKeyPairFromExistingPrivateKey(privateKey);

    final event = P2POrderEvent(
      id: '', // Se generará al firmar
      pubkey: keyPair.public,
      createdAt: createdAt,
      tags: tags,
      content: content,
      sig: '', // Se generará al firmar
    );

    event.sign(privateKey);
    return event;
  }
}
