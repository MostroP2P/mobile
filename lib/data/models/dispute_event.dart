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
      createdAt: _parseCreatedAt(json['createdAt']),
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

  static int _parseCreatedAt(dynamic v) {
    if (v is int) {
      // Treat values < 1_000_000_000_000 as seconds and multiply by 1000
      return v < 1000000000000 ? v * 1000 : v;
    }
    if (v is String) {
      DateTime? parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed.millisecondsSinceEpoch;
    }
    // Default fallback
    return DateTime.now().millisecondsSinceEpoch;
  }
}