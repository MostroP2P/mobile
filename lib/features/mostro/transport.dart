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
/// - `1` → [Transport.giftWrap] (v1, explicitly advertised).
/// - `null` → [Transport.giftWrap]. The tag is absent or the node info has not
///   been fetched yet; during the migration window this is the common legacy
///   case, so it resolves to v1 without noise.
/// - any other value → [Transport.giftWrap], logged at `warn`. We do not speak
///   that protocol, so we degrade to v1 (version-skew guard) and surface the
///   degraded state so a misconfigured node is not silently mis-paired.
Transport resolveTransport(int? protocolVersion) {
  switch (protocolVersion) {
    case 2:
      return Transport.nip44;
    case 1:
    case null:
      return Transport.giftWrap;
    default:
      logger.w(
        'Unsupported protocol_version $protocolVersion; '
        'degrading to v1 gift wrap',
      );
      return Transport.giftWrap;
  }
}
