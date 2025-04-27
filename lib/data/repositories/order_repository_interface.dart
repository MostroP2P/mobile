abstract class OrderRepository<T> {
  void dispose();
  Future<void> addOrder(T order);
  Future<List<T>> getAllOrders();
  Future<T?> getOrderById(String orderId);
  Future<void> updateOrder(T order);
  Future<void> deleteOrder(String orderId);
}
