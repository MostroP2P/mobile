import 'package:mostro_mobile/features/mostro/mostro_instance.dart';

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
/// `protocol_version` (§4.1).
///
/// Phase A (dual receive) keeps the v1 path behaviourally unchanged, so this
/// always resolves to [Transport.giftWrap]. Phase C (auto-detection and wiring)
/// replaces the body with the real per-node resolution driven by
/// [MostroInstance.protocolVersion] and the explicit downgrade logging required
/// by the version-skew guard.
Transport resolveTransport(MostroInstance? instance) => Transport.giftWrap;
