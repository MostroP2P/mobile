/// Stub model for DisputeEvent - UI only implementation
class DisputeEvent {
  final String id;
  final String disputeId;
  final String orderId;
  final String status;
  final int createdAt;

  DisputeEvent({
    required this.id,
    required this.disputeId,
    required this.orderId,
    required this.status,
    required this.createdAt,
  });

  factory DisputeEvent.fromJson(Map<String, dynamic> json) {
    return DisputeEvent(
      id: json['id'] ?? '',
      disputeId: json['disputeId'] ?? '',
      orderId: json['orderId'] ?? '',
      status: json['status'] ?? 'unknown',
      createdAt: json['createdAt'] ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'disputeId': disputeId,
      'orderId': orderId,
      'status': status,
      'createdAt': createdAt,
    };
  }
}