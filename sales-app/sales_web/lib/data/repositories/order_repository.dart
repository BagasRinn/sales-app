import '../../core/api_service.dart';
import '../models/order.dart';

class OrderRepository {
  final ApiService _api;

  OrderRepository(this._api);

  Future<SalesStats> getMyStats() async {
    final data = await _api.get('/orders/my/stats');
    return SalesStats.fromJson(data as Map<String, dynamic>);
  }

  Future<List<Order>> getMyOrders({
    int skip = 0,
    int limit = 20,
    String? status,
    String? search,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    final data = await _api.get('/orders/my', queryParams: params);
    final list = data['orders'] as List<dynamic>? ?? data as List<dynamic>;
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Order> getOrderDetail(String orderId) async {
    final data = await _api.get('/orders/$orderId');
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> createOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    required String orderType,
  }) async {
    final data = await _api.post('/orders', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes,
      'order_type': orderType,
    });
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> updateOrder({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    required String orderType,
  }) async {
    final data = await _api.put('/orders/$orderId', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes,
      'order_type': orderType,
    });
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<void> submitOrder(String orderId) async {
    await _api.post('/orders/$orderId/submit');
  }

  Future<void> deleteOrder(String orderId) async {
    await _api.delete('/orders/$orderId');
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.post('/orders/$orderId/cancel');
  }
}
