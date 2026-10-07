import 'package:mostro_mobile/data/models/payload.dart';

/// Payload of `export-reputation`: the identity the attestation will name,
/// and an optional rebind authorisation (event JSON) signed by the identity
/// the account is currently bound to. The source account is never named:
/// the node attests the identity the transport proves.
class ReputationExportRequest implements Payload {
  final String destination;
  final String? rebind;

  const ReputationExportRequest({required this.destination, this.rebind});

  factory ReputationExportRequest.fromJson(Map<String, dynamic> json) =>
      ReputationExportRequest(
        destination: json['destination'] as String,
        rebind: json['rebind'] as String?,
      );

  @override
  String get type => 'reputation_export_request';

  @override
  Map<String, dynamic> toJson() => {
        type: {'destination': destination, 'rebind': rebind},
      };
}
