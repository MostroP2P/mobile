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
/// [resolveAnchoredTransport], which additionally refuses to walk a node back
/// to a transport older than one it has already been verified to speak.
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

/// Combines what a node advertises *now* with the highest version it has
/// previously been verified to advertise, taking the higher of the two.
///
/// [advertised] comes from the node's current kind-38385 info event, and
/// [remembered] from [ProtocolVersionStore]. Both may be null: null
/// [advertised] means no info event is in hand, null [remembered] means this
/// client has never verified one from that node.
///
/// Taking the maximum is what makes the ratchet hold. Upgrades pass straight
/// through, while a claim that a node speaks something *older* than it has
/// already been proven to speak is ignored — that claim is only ever reachable
/// by a relay replaying or suppressing events, never by the node itself under
/// a migration that only moves forward.
int? anchoredProtocolVersion(int? advertised, int? remembered) {
  if (remembered == null) return advertised;
  if (advertised == null) return remembered;
  return advertised > remembered ? advertised : remembered;
}

/// [resolveTransport] applied to [anchoredProtocolVersion] — the resolution
/// every caller should use once a [ProtocolVersionStore] is reachable.
Transport resolveAnchoredTransport(int? advertised, int? remembered) {
  return resolveTransport(anchoredProtocolVersion(advertised, remembered));
}
