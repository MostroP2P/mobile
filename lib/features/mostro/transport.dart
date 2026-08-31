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

/// Resolves the wire transport for a node from its advertised
/// `protocol_version` (§2, §4.1).
///
/// - `2` → [Transport.nip44] (v2).
/// - `1` → [Transport.giftWrap] (v1, explicitly advertised). This is the only
///   input that selects the legacy gift wrap path.
/// - `null` → [Transport.nip44]. The tag is absent or the node info has not
///   been fetched yet. Advertising `protocol_version` is mandatory and gift
///   wrap is obsolete in the protocol, so "unknown" has exactly one sensible
///   answer: the live transport. Defaulting to v1 here used to cost a
///   kind-1059 REQ on every relay at every cold start, CLOSEd and re-REQd as
///   kind 14 the moment the info event landed.
/// - any other value → [Transport.nip44], logged at `warn`. The old rule
///   degraded to v1 as a version-skew guard; that guard was worth its cost
///   only while v1 was the live transport. A node advertising a version we do
///   not know (3, say) is far likelier to speak v2 than the obsolete v1, so
///   the safer guess is v2 — the `warn` still surfaces the skew.
Transport resolveTransport(int? protocolVersion) {
  switch (protocolVersion) {
    case 1:
      // Legacy nodes only: the gift wrap transport is obsolete in the
      // protocol and its code paths are scheduled for removal.
      return Transport.giftWrap;
    case 2:
    case null:
      // v2 is the live transport. Defaulting to it when the node info has
      // not arrived yet avoids a useless kind-1059 REQ at every cold start
      // followed by a CLOSE + re-REQ once protocol_version resolves.
      return Transport.nip44;
    default:
      logger.w(
        'Unknown protocol_version $protocolVersion; assuming v2 (NIP-44)',
      );
      return Transport.nip44;
  }
}
