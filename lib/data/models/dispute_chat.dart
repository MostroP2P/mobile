/// Stub model for DisputeChat - UI only implementation
class DisputeChat {
  final String id;
  final String message;
  final DateTime timestamp;
  final bool isFromUser;
  final String? adminPubkey;
  final bool isPending;
  final String? error;

  DisputeChat({
    required this.id,
    required this.message,
    required this.timestamp,
    required this.isFromUser,
    this.adminPubkey,
    this.isPending = false,
    this.error,
  });

  factory DisputeChat.fromJson(Map<String, dynamic> json) {
    return DisputeChat(
      id: json['id'] ?? '',
      message: json['message'] ?? '',
      timestamp: _parseTimestamp(json['timestamp']),
      isFromUser: json['isFromUser'] ?? false,
      adminPubkey: json['adminPubkey'],
      isPending: json['isPending'] ?? false,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isFromUser': isFromUser,
      'adminPubkey': adminPubkey,
      'isPending': isPending,
      'error': error,
    };
  }

  /// Create a copy with updated fields
  DisputeChat copyWith({
    String? id,
    String? message,
    DateTime? timestamp,
    bool? isFromUser,
    String? adminPubkey,
    bool? isPending,
    String? error,
  }) {
    return DisputeChat(
      id: id ?? this.id,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isFromUser: isFromUser ?? this.isFromUser,
      adminPubkey: adminPubkey ?? this.adminPubkey,
      isPending: isPending ?? this.isPending,
      error: error ?? this.error,
    );
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