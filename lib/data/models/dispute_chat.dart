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
      timestamp: _parseTimestamp(json['timestamp']),
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

  static DateTime _parseTimestamp(dynamic v) {
    if (v is int) {
      // Treat values < 1e12 as seconds, convert to milliseconds
      int milliseconds = v < 1e12 ? v * 1000 : v;
      return DateTime.fromMillisecondsSinceEpoch(milliseconds);
    }
    if (v is String && v.isNotEmpty) {
      DateTime? parsed = DateTime.tryParse(v);
      if (parsed != null) return parsed;
    }
    // Final fallback
    return DateTime.now();
  }
}