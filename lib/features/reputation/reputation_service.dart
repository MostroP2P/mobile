import 'dart:async';
import 'dart:convert';

import 'package:dart_nostr/nostr/core/key_pairs.dart';
import 'package:dart_nostr/nostr/model/event/event.dart';
import 'package:dart_nostr/nostr/model/request/filter.dart';
import 'package:dart_nostr/nostr/model/request/request.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mostro_mobile/data/models.dart';
import 'package:mostro_mobile/data/models/enums/action.dart';
import 'package:mostro_mobile/data/models/enums/storage_keys.dart';
import 'package:mostro_mobile/features/key_manager/key_manager_provider.dart';
import 'package:mostro_mobile/features/mostro/mostro_instance.dart';
import 'package:mostro_mobile/features/reputation/reputation_attestation.dart';
import 'package:mostro_mobile/features/settings/settings_provider.dart';
import 'package:mostro_mobile/services/logger_service.dart';
import 'package:mostro_mobile/shared/utils/nostr_utils.dart';
import 'package:mostro_mobile/shared/providers/nostr_service_provider.dart';
import 'package:mostro_mobile/shared/providers/order_repository_provider.dart';
import 'package:mostro_mobile/shared/providers/storage_providers.dart';

/// Why an export or import did not happen: a `cant-do` reason from the node
/// (snake_case, e.g. `reputation_already_imported`), a reason the client found
/// itself with the same names, or one of [ReputationService.nodeDoesNotExport],
/// [ReputationService.nodeDoesNotImport] and [ReputationService.noResponse].
class ReputationException implements Exception {
  final String reason;

  const ReputationException(this.reason);

  @override
  String toString() => 'ReputationException($reason)';
}

/// Sends one identity-level request to a node and returns the first reply on
/// the trade key it was sent from, as the message map (`tuple[0]`).
abstract class ReputationTransport {
  Future<Map<String, dynamic>> request(
    MostroMessage message, {
    required String node,
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs identity,
  });
}

/// [ReputationTransport] over the app's relays: subscribes on the trade key
/// before publishing, like the restore flow, and waits for the node's reply.
class NostrReputationTransport implements ReputationTransport {
  final Ref ref;
  final Duration timeout;

  NostrReputationTransport(this.ref,
      {this.timeout = const Duration(seconds: 15)});

  @override
  Future<Map<String, dynamic>> request(
    MostroMessage message, {
    required String node,
    required NostrKeyPairs tradeKey,
    required NostrKeyPairs identity,
  }) async {
    final instance =
        await ref.read(orderRepositoryProvider).awaitMostroInstance();
    final nostr = ref.read(nostrServiceProvider);
    final reply = Completer<NostrEvent>();
    final subscription = nostr
        .subscribeToEvents(NostrRequest(filters: [
      NostrFilter(kinds: [14], authors: [node], p: [tradeKey.public], limit: 0),
    ]))
        .listen((event) {
      if (!reply.isCompleted) reply.complete(event);
    });
    try {
      final event = await message.wrapForTransport(
        protocolVersion: instance?.protocolVersion,
        tradeKey: tradeKey,
        recipientPubKey: node,
        masterKey: identity,
        difficulty: instance?.pow ?? 0,
      );
      await nostr.publishEvent(event);
      final answer = await reply.future.timeout(
        timeout,
        onTimeout: () =>
            throw const ReputationException(ReputationService.noResponse),
      );
      // Nodes that advertise these actions speak protocol v2: a kind 14
      // NIP-44 direct message whose content is the message tuple.
      final content = await NostrUtils.decryptNIP44DirectEvent(
        answer,
        tradeKey.private,
        expectedAuthor: node,
      );
      final tuple = jsonDecode(content) as List<dynamic>;
      return tuple.first as Map<String, dynamic>;
    } finally {
      await subscription.cancel();
    }
  }
}

/// Export the user's reputation from the selected node, and import an
/// attestation into it (MostroP2P/protocol reputation_transfer.md).
///
/// Both act on the identity key, so neither runs in full privacy mode. A
/// request goes only to a node whose info event advertises it: a node that
/// predates these actions cannot parse them and would never answer.
class ReputationService {
  static const nodeDoesNotExport = 'node_does_not_export';
  static const nodeDoesNotImport = 'node_does_not_import';
  static const noResponse = 'no_response';

  final Ref ref;
  final ReputationTransport transport;
  final int Function() now;

  ReputationService(
    this.ref, {
    ReputationTransport? transport,
    int Function()? now,
  })  : transport = transport ?? NostrReputationTransport(ref),
        now = now ?? (() => DateTime.now().millisecondsSinceEpoch ~/ 1000);

  /// Ask the node to attest the user's reputation there for [destination]
  /// (the user's own identity by default). Before the first export the UI
  /// confirms the destination with the user: the request itself binds the
  /// account to it. [rebind] moves an existing binding (see [signRebind]).
  /// The attestation is verified, kept until imported, and returned.
  Future<ReputationAttestation> exportReputation({
    String? destination,
    String? rebind,
  }) async {
    final node = ref.read(settingsProvider).mostroPublicKey;
    final instance =
        await ref.read(orderRepositoryProvider).awaitMostroInstance();
    final issuer = instance?.reputationIssuer;
    if (issuer == null) throw const ReputationException(nodeDoesNotExport);
    final identity = _identity();
    final target = destination ?? identity.public;
    final reply = await _send(
      node,
      identity,
      Action.exportReputation,
      ReputationExportRequest(destination: target, rebind: rebind),
    );
    if (reply.action != Action.reputationExported ||
        reply.payload is! ReputationAttestationPayload) {
      throw const ReputationException('invalid_payload');
    }
    final json = (reply.payload as ReputationAttestationPayload).attestation;
    final attestation = _parse(json);
    if (attestation.issuer != issuer || attestation.destination != target) {
      throw const ReputationException('invalid_reputation_attestation');
    }
    await ref.read(sharedPreferencesProvider).setString(
        SharedPreferencesKeys.pendingReputationAttestation.value, json);
    logger.i('Reputation: exported ${attestation.reviews} ratings from $node');
    return attestation;
  }

  /// Import [json] into the selected node. It must name the user's identity
  /// and be signed by a key the node advertises it trusts; the node runs the
  /// full checks and answers `reputation-imported` or a `cant-do`.
  Future<ReputationAttestation> importReputation(String json) async {
    final node = ref.read(settingsProvider).mostroPublicKey;
    final instance =
        await ref.read(orderRepositoryProvider).awaitMostroInstance();
    final trusted = instance?.reputationImportIssuers;
    if (trusted == null) throw const ReputationException(nodeDoesNotImport);
    final identity = _identity();
    final attestation = _parse(json);
    if (attestation.destination != identity.public) {
      throw const ReputationException('reputation_identity_mismatch');
    }
    if (!trusted.contains(attestation.issuer)) {
      throw const ReputationException('untrusted_reputation_issuer');
    }
    final reply = await _send(
      node,
      identity,
      Action.importReputation,
      ReputationAttestationPayload(attestation.json),
    );
    if (reply.action != Action.reputationImported) {
      throw const ReputationException('invalid_payload');
    }
    final prefs = ref.read(sharedPreferencesProvider);
    const key = SharedPreferencesKeys.pendingReputationAttestation;
    if (await prefs.getString(key.value) == json) await prefs.remove(key.value);
    logger.i('Reputation: imported ${attestation.reviews} ratings into $node');
    return attestation;
  }

  /// The attestation exported last and not imported yet, if still valid.
  Future<ReputationAttestation?> pendingAttestation() async {
    final json = await ref
        .read(sharedPreferencesProvider)
        .getString(SharedPreferencesKeys.pendingReputationAttestation.value);
    if (json == null) return null;
    try {
      return ReputationAttestation.parse(json, now: now());
    } on AttestationException {
      return null;
    }
  }

  /// Sign, with the identity the account is bound to now, the authorisation
  /// to move the binding at [issuer] to [newIdentity]. Pass it as `rebind` to
  /// [exportReputation] from the new identity, or paste it into lnp2pBot.
  String signRebind({required String issuer, required String newIdentity}) =>
      ReputationRebind.build(
        boundIdentity: _identity(),
        issuer: issuer,
        newIdentity: newIdentity,
        createdAt: now(),
      );

  NostrKeyPairs _identity() {
    if (ref.read(settingsProvider).fullPrivacyMode) {
      throw const ReputationException('reputation_identity_required');
    }
    final identity = ref.read(keyManagerProvider).masterKeyPair;
    if (identity == null) {
      throw const ReputationException('reputation_identity_required');
    }
    return identity;
  }

  ReputationAttestation _parse(String json) {
    try {
      return ReputationAttestation.parse(json, now: now());
    } on AttestationException catch (e) {
      throw ReputationException(e.reason);
    }
  }

  Future<MostroMessage> _send(
    String node,
    NostrKeyPairs identity,
    Action action,
    Payload payload,
  ) async {
    final keyManager = ref.read(keyManagerProvider);
    final tradeKey = await keyManager
        .deriveTradeKeyFromIndex(await keyManager.getNextKeyIndex());
    final map = await transport.request(
      MostroMessage(
        action: action,
        requestId: DateTime.now().millisecondsSinceEpoch,
        payload: payload,
      ),
      node: node,
      tradeKey: tradeKey,
      identity: identity,
    );
    final reply = MostroMessage.fromJson(map);
    if (reply.action == Action.cantDo && reply.payload is CantDo) {
      throw ReputationException((reply.payload as CantDo).cantDoReason.value);
    }
    return reply;
  }
}

final reputationServiceProvider = Provider<ReputationService>(
  (ref) => ReputationService(ref),
);
