import 'package:mostro_mobile/data/models/payload.dart';

class Dispute implements Payload {
  final String disputeId;

  Dispute({required this.disputeId}) {
    if (disputeId.isEmpty) {
      throw ArgumentError('Dispute ID cannot be empty');
    }
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      type: disputeId,
    };
  }

  factory Dispute.fromJson(Map<String, dynamic> json) {
    try {
      
      final oid = json['dispute'];
      if (oid == null) {
        throw FormatException('Missing required field: dispute');
      }
      
      String disputeIdValue;
      if (oid is List) {
        if (oid.isEmpty) {
          throw FormatException('Dispute list cannot be empty');
        }
        disputeIdValue = oid[0]?.toString() ?? 
          (throw FormatException('First element of dispute list is null'));
      } else {
        disputeIdValue = oid.toString();
      }
      
      if (disputeIdValue.isEmpty) {
        throw FormatException('Dispute ID cannot be empty');
      }
      
      return Dispute(disputeId: disputeIdValue);
    } catch (e) {
      throw FormatException('Failed to parse Dispute from JSON: $e');
    }
  }

  @override
  String get type => 'dispute';
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Dispute && other.disputeId == disputeId;
  }
  
  @override
  int get hashCode => disputeId.hashCode;
  
  @override
  String toString() => 'Dispute(disputeId: $disputeId)';
}
