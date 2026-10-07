import 'package:mostro_mobile/data/models/payload.dart';

/// A reputation attestation (kind 38388) serialised as event JSON, carried by
/// `reputation-exported` and `import-reputation`. Forwarded unchanged; parse
/// it with `ReputationAttestation.parse`.
class ReputationAttestationPayload implements Payload {
  final String attestation;

  const ReputationAttestationPayload(this.attestation);

  @override
  String get type => 'reputation_attestation';

  @override
  Map<String, dynamic> toJson() => {type: attestation};
}
