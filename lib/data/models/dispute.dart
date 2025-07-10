import 'package:mostro_mobile/data/models/payload.dart';

class Dispute implements Payload {
  final String disputeId;

  Dispute({required this.disputeId});

  @override
  Map<String, dynamic> toJson() {
    return {
      type: disputeId,
    };
  }

  factory Dispute.fromJson(Map<String, dynamic> json) {
    final oid = json['dispute'];
    return Dispute(
      disputeId: oid is List ? oid[0] : oid,
    );
  }

  @override
  String get type => 'dispute';
}
