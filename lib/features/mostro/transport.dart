import 'package:mostro_mobile/services/logger_service.dart';

/// Wire transport a Mostro node speaks.
///
/// - [giftWrap]: protocol v1, NIP-59 gift wrap (kind 1059).
/// - [nip44]: protocol v2, NIP-44 direct message signed by the trade key
///   (kind 14).
///
/// Modelled as an enum (rather than a raw integer threaded through the code) so
/// the send path, the receive subscription filters and the message `version`
/// field cannot drift out of sync. See
/// `docs/architecture/TRANSPORT_V2_MIGRATION.md` (§4.1).
enum Transport { giftWrap, nip44 }

/// Transport assumed when nothing is known about a node.
///
/// v2 (kind 14), matching mostrod's own default: since v0.18.0 the daemon
/// subscribes to exactly one kind and picks nip44 unless an operator opts into
/// gift-wrap explicitly, and v0.19.0 removes the choice entirely (issue #786).
///
/// The direction of this default is a security property, not a guess about
/// what most nodes run. "Unknown" used to mean v1, whose intake authenticates
/// nothing — so a relay could pin a client to the forgeable transport just by
/// *withholding* the node's info event, no forgery required. Defaulting the
/// other way makes the failure mode a brief deafness against a genuine v1 node
/// (self-healing the moment its signed info event arrives) instead of a silent
/// downgrade.
const Transport kDefaultTransport = Transport.nip44;

/// The version a node states by *omitting* the `protocol_version` tag from an
/// otherwise valid info event.
///
/// Legacy daemons (pre-v0.18.0) never emit the tag, so on a verified,
/// non-superseded info event an absent tag is v1 asserted by omission. That is
/// a different fact from having no info event at all, and the two must not
/// collapse into the same `null`: the first is evidence about the node, the
/// second is the absence of evidence. Reading a legacy node's silence as
/// [kDefaultTransport] would pin the client to kind 14 against a node that only
/// ever listens on kind 1059 — a permanent, self-inflicted partition.
const int kLegacyProtocolVersion = 1;

/// Resolves the wire transport for a node from its advertised
/// `protocol_version` (§2, §4.1).
///
/// - `1` → [Transport.giftWrap] (v1, explicitly advertised).
/// - `2` → [Transport.nip44] (v2).
/// - `null` → [kDefaultTransport]. The tag is absent, the node info has not
///   been fetched yet, or a relay is withholding it.
/// - any other value → [kDefaultTransport], logged at `warn`. We do not speak
///   that protocol; falling back to v1 here would hand any party who can put a
///   number in that tag a downgrade primitive, so an unrecognised version
///   degrades *upwards* to the safe default instead.
///
/// Callers that can reach a [ProtocolVersionStore] should prefer
/// [resolveAnchoredTransport], which additionally refuses to take a node's
/// transport from an assertion older than one this client has already
/// verified.
Transport resolveTransport(int? protocolVersion) {
  switch (protocolVersion) {
    case 1:
      return Transport.giftWrap;
    case 2:
      return Transport.nip44;
    case null:
      return kDefaultTransport;
    default:
      logger.w(
        'Unsupported protocol_version $protocolVersion; '
        'falling back to $kDefaultTransport',
      );
      return kDefaultTransport;
  }
}

/// A protocol version together with the moment the node asserted it.
///
/// [createdAt] is the signed `created_at` of the kind-38385 info event that
/// carried the version. That field sits *inside* the signature, so a relay can
/// replay an assertion but cannot re-date one. This is what lets
/// [anchoredProtocolVersion] tell a replayed old event apart from the node
/// genuinely changing what it speaks.
class VersionAssertion {
  final int version;

  /// Null when the event carried no usable `created_at`. An assertion that
  /// cannot be dated cannot be ranked by freshness, so it falls back to the
  /// conservative comparison — see [anchoredProtocolVersion].
  final DateTime? createdAt;

  const VersionAssertion(this.version, this.createdAt);

  @override
  bool operator ==(Object other) =>
      other is VersionAssertion &&
      other.version == version &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(version, createdAt);

  @override
  String toString() => 'VersionAssertion($version, $createdAt)';
}

/// Combines what a node advertises *now* with what it has previously been
/// verified to advertise, letting the more recent signed assertion win.
///
/// [advertised] comes from the node's current kind-38385 info event, and
/// [remembered] from [ProtocolVersionStore]. Both may be null: null
/// [advertised] means no info event is in hand, null [remembered] means this
/// client has never verified one from that node.
///
/// Freshness — not the higher number — is what makes the anchor hold. The
/// threat is a relay withholding the node's current info event and serving an
/// older signed one in its place; a relay can choose *which* events it serves,
/// but it cannot mint one, and it cannot move an existing one forward in time
/// without breaking the signature. So the newest assertion this client has ever
/// verified is exactly the evidence a relay cannot manufacture, and preferring
/// it blocks the downgrade.
///
/// Anchoring on the *highest* version instead would block one more thing it
/// should not: the node itself moving back to v1. mostrod 0.18.x still ships
/// `transport = "gift-wrap"`, so an operator who rolls back a bad v2 rollout
/// publishes a genuine, newer, signed v1 assertion — and a client that refused
/// it would be partitioned from that node for good, silently, with no way back
/// short of reinstalling.
///
/// When the two assertions carry the same timestamp — or either cannot be dated
/// — freshness cannot separate them and the higher version wins. NIP-01's
/// tie-break on event id already runs upstream in `OpenOrdersRepository`, so a
/// tie here is between an assertion in hand and one recalled from an earlier
/// session; resolving it upwards keeps a same-second replay from lowering the
/// anchor.
int? anchoredProtocolVersion(
  VersionAssertion? advertised,
  VersionAssertion? remembered,
) {
  if (remembered == null) return advertised?.version;
  if (advertised == null) return remembered.version;

  final advertisedAt = advertised.createdAt;
  final rememberedAt = remembered.createdAt;
  if (advertisedAt != null && rememberedAt != null) {
    if (advertisedAt.isAfter(rememberedAt)) return advertised.version;
    if (rememberedAt.isAfter(advertisedAt)) return remembered.version;
  }

  return advertised.version > remembered.version
      ? advertised.version
      : remembered.version;
}

/// [resolveTransport] applied to [anchoredProtocolVersion] — the resolution
/// every caller should use once a [ProtocolVersionStore] is reachable.
Transport resolveAnchoredTransport(
  VersionAssertion? advertised,
  VersionAssertion? remembered,
) {
  return resolveTransport(anchoredProtocolVersion(advertised, remembered));
}
