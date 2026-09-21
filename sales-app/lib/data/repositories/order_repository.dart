import '../models/order.dart';
import 'api_service.dart';

class OrderRepository {
  final ApiService _api;

  OrderRepository(this._api);

  Future<Order> checkout(
    List<Map<String, dynamic>> items, {
    String? storeName,
    String? storeContact,
    String? storeAddress,
  }) async {
    final data = await _api.post('/orders', body: {
      'items': items,
      'store_name': storeName ?? '',
      'store_contact': storeContact ?? '',
      'store_address': storeAddress ?? '',
    });
    return Order.fromJson(data);
  }

  Future<List<Order>> getMyOrders({
    int skip = 0,
    int limit = 50,
    String? status,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (status != null) {
      queryParams['status'] = status;
    }

    final data = await _api.get('/orders/my', queryParams: queryParams);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<Order> getOrderDetail(String orderId) async {
    final data = await _api.get('/orders/$orderId');
    return Order.fromJson(data);
  }

  Future<void> cancelOrder(String orderId) async {
    await _api.post('/orders/$orderId/cancel');
  }
}
