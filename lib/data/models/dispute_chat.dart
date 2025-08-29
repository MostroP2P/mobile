/// Stub model for DisputeChat - UI only implementation
class DisputeChat {
  final String id;
  final String message;
  final DateTime timestamp;
  final bool isFromUser;
  final String? adminPubkey;

  DisputeChat({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.isFromUser,
    this.adminPubkey,
  });

  factory DisputeChat.fromJson(Map<String, dynamic> json) {
    return DisputeChat(
      id: json['id'] ?? '',
      message: json['message'] ?? '',
      timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
      isFromUser: json['isFromUser'] ?? false,
      adminPubkey: json['adminPubkey'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isFromUser': isFromUser,
      'adminPubkey': adminPubkey,
    };
  }
}