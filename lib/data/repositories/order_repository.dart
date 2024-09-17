import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/order_model.dart';

class OrderRepository {
  final String _baseUrl =
      'https://api.mostro.network'; // Asume que esta es tu URL base

  Future<List<OrderModel>> getOrders() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/orders'));

      if (response.statusCode == 200) {
        final List<dynamic> ordersJson = json.decode(response.body);
        return ordersJson.map((json) => OrderModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load orders');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<OrderModel> createOrder(OrderModel order) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/orders'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(order.toJson()),
      );

      if (response.statusCode == 201) {
        return OrderModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to create order');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<OrderModel> getOrderById(String id) async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/orders/$id'));

      if (response.statusCode == 200) {
        return OrderModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Failed to load order');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<void> updateOrder(OrderModel order) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/orders/${order.id}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(order.toJson()),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to update order');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }

  Future<void> deleteOrder(String id) async {
    try {
      final response = await http.delete(Uri.parse('$_baseUrl/orders/$id'));

      if (response.statusCode != 200) {
        throw Exception('Failed to delete order');
      }
    } catch (e) {
      throw Exception('Failed to connect to the server: $e');
    }
  }
}
