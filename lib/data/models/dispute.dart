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

  factory Dispute.fromJson(List<dynamic> json) {
    final oid = json[0];
    return Dispute(
      disputeId: oid,
    );
  }


  @override
  String get type => 'dispute';
}
