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
    if (status?.isNotEmpty ?? false) {
      params['status'] = status!;
    }
    if (search?.isNotEmpty ?? false) {
      params['search'] = search!;
    }
    final data = await _api.get('/orders/my', queryParams: params);
    // /orders/my returns a bare JSON array per FastAPI's response_model.
    // The previous `data['orders'] ?? data as List` form threw on a List
    // response because `data['orders']` raises before the `??` fallback is
    // considered — list indices must be int, not String. Match the mobile
    // app's pattern: type-check first, then unwrap.
    final list = data is List
        ? data
        : data is Map
            ? (data['orders'] as List<dynamic>? ?? const <dynamic>[])
            : const <dynamic>[];
    return list
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
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
    String? clientRequestId,
    String orderDiscountType = 'PERCENT',
    int orderDiscountNominal = 0,
    String orderUpPriceType = 'NOMINAL',
    int orderUpPriceNominal = 0,
  }) async {
    final body = <String, dynamic>{
      'customer_id': customerId,
      'items': items,
      'notes': notes,
      'order_type': orderType,
      'order_discount_type': orderDiscountType,
      'order_discount_nominal': orderDiscountNominal,
      'order_up_price_type': orderUpPriceType,
      'order_up_price_nominal': orderUpPriceNominal,
    };
    if (clientRequestId != null) {
      body['client_request_id'] = clientRequestId;
    }
    final data = await _api.post('/orders', body: body);
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> saveDraft({
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    required String orderType,
    String? existingOrderId,
    String? clientRequestId,
    String orderDiscountType = 'PERCENT',
    int orderDiscountNominal = 0,
    String orderUpPriceType = 'NOMINAL',
    int orderUpPriceNominal = 0,
  }) async {
    final body = <String, dynamic>{
      'customer_id': customerId,
      'items': items,
      'notes': notes,
      'order_type': orderType,
      'status': 'DRAFT',
      'order_discount_type': orderDiscountType,
      'order_discount_nominal': orderDiscountNominal,
      'order_up_price_type': orderUpPriceType,
      'order_up_price_nominal': orderUpPriceNominal,
    };
    if (clientRequestId != null) {
      body['client_request_id'] = clientRequestId;
    }
    final data = existingOrderId != null
        ? await _api.put('/orders/$existingOrderId', body: body)
        : await _api.post('/orders', body: body);
    return Order.fromJson(data as Map<String, dynamic>);
  }

  Future<Order> updateOrder({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    String? notes,
    required String orderType,
    String orderDiscountType = 'PERCENT',
    int orderDiscountNominal = 0,
    String orderUpPriceType = 'NOMINAL',
    int orderUpPriceNominal = 0,
  }) async {
    final data = await _api.put('/orders/$orderId', body: {
      'customer_id': customerId,
      'items': items,
      'notes': notes,
      'order_type': orderType,
      'order_discount_type': orderDiscountType,
      'order_discount_nominal': orderDiscountNominal,
      'order_up_price_type': orderUpPriceType,
      'order_up_price_nominal': orderUpPriceNominal,
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
