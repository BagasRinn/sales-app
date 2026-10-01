import '../models/order.dart';
import 'api_service.dart';

class OrderRepository {
  final ApiService _api;

  OrderRepository(this._api);

  Future<Order> createOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String orderType = 'REGULER',
  }) async {
    final data = await _api.post('/orders', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes ?? '',
      'order_type': orderType,
    });
    return Order.fromJson(data);
  }

  Future<Order> updateOrder({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    String orderType = 'REGULER',
  }) async {
    final data = await _api.put('/orders/$orderId', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes ?? '',
      'order_type': orderType,
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

  /// Target sales untuk user yang login. Null kalau belum diset manager.
  Future<SalesTarget?> getMyTarget({String? period}) async {
    final qs = period != null ? '?period=${Uri.encodeComponent(period)}' : '';
    final data = await _api.get('/sales-targets/my$qs');
    if (data == null) return null;
    return SalesTarget.fromJson(data);
  }
}

class SalesStats {
  final int omsetHariIni;
  final int pendingCount;
  final int selesaiBulanIniCount;
  final int selesaiBulanIniTotal;

  // Target fields (optional — null kalau manager belum set)
  final String? targetType;
  final int? targetValue;
  final int? incentiveAmount;
  final String? targetPeriod;

  SalesStats({
    required this.omsetHariIni,
    required this.pendingCount,
    required this.selesaiBulanIniCount,
    required this.selesaiBulanIniTotal,
    this.targetType,
    this.targetValue,
    this.incentiveAmount,
    this.targetPeriod,
  });

  factory SalesStats.fromJson(Map<String, dynamic> json) {
    return SalesStats(
      omsetHariIni: json['omset_hari_ini'] as int? ?? 0,
      pendingCount: json['pending_count'] as int? ?? 0,
      selesaiBulanIniCount: json['selesai_bulan_ini_count'] as int? ?? 0,
      selesaiBulanIniTotal: json['selesai_bulan_ini_total'] as int? ?? 0,
      targetType: json['target_type'] as String?,
      targetValue: json['target_value'] as int?,
      incentiveAmount: json['incentive_amount'] as int?,
      targetPeriod: json['target_period'] as String?,
    );
  }
}

class SalesTarget {
  final String id;
  final String userId;
  final String period;
  final String targetType;
  final int targetValue;
  final int incentiveAmount;

  SalesTarget({
    required this.id,
    required this.userId,
    required this.period,
    required this.targetType,
    required this.targetValue,
    required this.incentiveAmount,
  });

  factory SalesTarget.fromJson(Map<String, dynamic> json) {
    return SalesTarget(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      period: json['period'] as String,
      targetType: json['target_type'] as String,
      targetValue: json['target_value'] as int? ?? 0,
      incentiveAmount: json['incentive_amount'] as int? ?? 0,
    );
  }

  bool get isOrderCount => targetType == 'ORDER_COUNT';
  bool get isRevenue => targetType == 'REVENUE';
}
