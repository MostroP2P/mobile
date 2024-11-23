abstract class OrderRepository {
  void dispose();
}

enum MessageKind {
  openOrder(8383),
  directMessage(1059);

  final int kind;
  const MessageKind(this.kind);
}

class OrderFilter {
  final List<MessageKind> messageKinds;

  OrderFilter({required this.messageKinds});
  
}
