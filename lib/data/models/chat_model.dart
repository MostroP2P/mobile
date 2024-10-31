class ChatModel {
  final String id;
  final String username;
  final String lastMessage;
  final String timeAgo;
  final bool isUnread;

  ChatModel({
    required this.id,
    required this.username,
    required this.lastMessage,
    required this.timeAgo,
    this.isUnread = false,
  });
}
