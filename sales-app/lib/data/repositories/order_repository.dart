import '../models/order.dart';
import 'api_service.dart';

class OrderRepository {
  final ApiService _api;

  OrderRepository(this._api);

  Future<Order> createOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final data = await _api.post('/orders', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes ?? '',
    });
    return Order.fromJson(data);
  }

  Future<Order> updateOrder({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
  }) async {
    final data = await _api.put('/orders/$orderId', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes ?? '',
    });
    return Order.fromJson(data);
  }

  Future<Order> submitOrder(String orderId) async {
    final data = await _api.post('/orders/$orderId/submit');
    return Order.fromJson(data);
  }

  Future<void> deleteOrder(String orderId) async {
    await _api.delete('/orders/$orderId');
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

  /// Dashboard stats untuk sales. Timezone dihitung di backend (WITA).
  Future<SalesStats> getMyStats() async {
    final data = await _api.get('/orders/my/stats');
    return SalesStats.fromJson(data);
  }
}

class SalesStats {
  final int omsetHariIni;
  final int pendingCount;
  final int selesaiBulanIniCount;
  final int selesaiBulanIniTotal;

  SalesStats({
    required this.omsetHariIni,
    required this.pendingCount,
    required this.selesaiBulanIniCount,
    required this.selesaiBulanIniTotal,
  });

  factory SalesStats.fromJson(Map<String, dynamic> json) {
    return SalesStats(
      omsetHariIni: json['omset_hari_ini'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      selesaiBulanIniCount: json['selesai_bulan_ini_count'] as int? ?? 0,
      selesaiBulanIniTotal: json['selesai_bulan_ini_total'] as int? ?? 0,
    );
  }
}
