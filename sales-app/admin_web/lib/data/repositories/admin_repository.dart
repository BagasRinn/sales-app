import 'package:dio/dio.dart';

import '../repositories/api_service.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/sync_result.dart';
import '../models/customer.dart';
import '../models/sales_user.dart';
import '../models/sales_assignment.dart';
import '../models/user_item.dart';

class AdminRepository {
  final ApiService _api;

  AdminRepository(this._api);

  Future<void> login(String username, String password) async {
    final resp = await _api.post('/auth/login', body: {'username': username, 'password': password});
    _api.setTokens(
      access: resp['access_token'],
      refresh: resp['refresh_token'],
    );
  }

  void setTokens(String access, String refresh) => _api.setTokens(access: access, refresh: refresh);
  void clearTokens() => _api.clearTokens();
  bool get hasToken => _api.hasToken;

  Future<List<Order>> getPendingOrders() async {
    final data = await _api.get('/orders/pending');
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  Future<List<Order>> getAllOrders({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    int skip = 0,
    int limit = 50,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-'
          '${dateFrom.month.toString().padLeft(2, '0')}-'
          '${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-'
          '${dateTo.month.toString().padLeft(2, '0')}-'
          '${dateTo.day.toString().padLeft(2, '0')}';
    }
    final qs = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/orders$qs');
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Sama dengan [getAllOrders] tapi juga baca header X-Total-Count —
  /// untuk pagination di client. Pakai Dio langsung agar bisa akses
  /// response.headers.
  Future<({List<Order> orders, int total})> getAllOrdersPaginated({
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    int skip = 0,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (dateFrom != null) {
      params['date_from'] =
          '${dateFrom.year.toString().padLeft(4, '0')}-'
          '${dateFrom.month.toString().padLeft(2, '0')}-'
          '${dateFrom.day.toString().padLeft(2, '0')}';
    }
    if (dateTo != null) {
      params['date_to'] =
          '${dateTo.year.toString().padLeft(4, '0')}-'
          '${dateTo.month.toString().padLeft(2, '0')}-'
          '${dateTo.day.toString().padLeft(2, '0')}';
    }
    final qs = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final response = await _api.dio.get<dynamic>(
      '/orders$qs',
      options: Options(responseType: ResponseType.json),
    );
    final data = response.data as List;
    final orders = data.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
    final totalHeader = response.headers.value('x-total-count');
    final total = int.tryParse(totalHeader ?? '') ?? orders.length;
    return (orders: orders, total: total);
  }

  Future<Order> getOrderDetail(String orderId) async {
    final data = await _api.get('/orders/$orderId');
    return Order.fromJson(data);
  }

  Future<void> approveOrder(String orderId) async {
    await _api.post('/orders/$orderId/approve');
  }

  Future<void> rejectOrder(String orderId) async {
    await _api.post('/orders/$orderId/reject');
  }

  /// Bulk update discount per item — dipakai admin untuk koreksi sebelum approve/reject.
  Future<Order> updateOrderDiscounts(
    String orderId,
    List<Map<String, dynamic>> items,
  ) async {
    final data = await _api.put('/orders/$orderId/discounts', body: {
      'items': items,
    });
    return Order.fromJson(data);
  }

  /// Download laporan harian sebagai bytes Excel. Caller yang handle
  /// blob URL / file save (browser download di web).
  Future<List<int>> downloadDailyReport({
    required DateTime date,
    List<String> statuses = const ['APPROVED'],
  }) async {
    final dateStr = '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final qs = '?date=$dateStr&status=${statuses.join(',')}';
    // Ambil raw bytes — pakai helper Dio langsung agar bypass deserialization JSON.
    final dio = _api.dio;
    final response = await dio.get<List<int>>(
      '/reports/daily$qs',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  Future<List<Product>> getProducts({int page = 0, int limit = 20, String? search, String? kategori, String? status}) async {
    final queryParams = {
      'skip': (page * limit).toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    final data = await _api.get('/products?$queryString');
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<String>> getKategoriList() async {
    final data = await _api.get('/products/kategori');
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<int> getProductCount({String? search, String? kategori, String? status}) async {
    final queryParams = {
      if (search != null && search.isNotEmpty) 'search': search,
      if (kategori != null && kategori.isNotEmpty) 'kategori': kategori,
      if (status != null && status.isNotEmpty) 'status': status,
    };
    final queryString = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/products/count$queryString');
    return data['total'] as int;
  }

  Future<Product> getProduct(String productId) async {
    final data = await _api.get('/products/$productId');
    return Product.fromJson(data);
  }

  Future<void> overrideStock(String productId, int stokSistem) async {
    await _api.put('/products/$productId/stock', body: {'stok_sistem': stokSistem});
  }

  Future<void> deleteProduct(String productId) async {
    await _api.delete('/products/$productId');
  }

  Future<SyncResult> syncProducts() async {
    final data = await _api.post('/products/sync');
    return SyncResult.fromJson(data);
  }

  Future<SyncResult> importExcel(List<int> fileBytes, String fileName) async {
    final data = await _api.postFile('/products/import-excel', fileBytes, fileName);
    return SyncResult.fromJson(data);
  }

  Future<SyncResult> importCustomersExcel(List<int> fileBytes, String fileName) async {
    final data = await _api.postFile('/customers/import-excel', fileBytes, fileName);
    return SyncResult.fromJson(data);
  }

  Future<List<Customer>> getCustomers({int page = 0, int limit = 20, String? search}) async {
    final queryParams = {
      'skip': (page * limit).toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = queryParams.entries.map((e) => '${e.key}=${e.value}').join('&');
    final data = await _api.get('/customers?$queryString');
    return (data as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<int> getCustomerCount({String? search}) async {
    final queryParams = {
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = queryParams.isEmpty ? '' : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/customers/count$queryString');
    return data['total'] as int;
  }

  Future<Customer> getCustomer(String customerId) async {
    final data = await _api.get('/customers/$customerId');
    return Customer.fromJson(data);
  }

  Future<Customer> updateCustomer(String customerId, Map<String, dynamic> body) async {
    final data = await _api.put('/customers/$customerId', body: body);
    return Customer.fromJson(data);
  }

  Future<void> deleteCustomer(String customerId) async {
    await _api.delete('/customers/$customerId');
  }

  Future<List<SalesAssignment>> getCustomerAssignments(String customerId) async {
    final data = await _api.get('/customers/$customerId/assignments');
    return (data as List).map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SalesAssignment>> assignCustomerSales(String customerId, List<String> salesIds) async {
    final data = await _api.post('/customers/$customerId/assign', body: {
      'sales_ids': salesIds,
    });
    return (data as List).map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<SalesUser>> listSalesUsers() async {
    final data = await _api.get('/users/sales');
    return (data as List).map((e) => SalesUser.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<UserItem>> getUsers({String? role, String? search}) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final qs = params.isEmpty ? '' : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/users$qs');
    return (data as List).map((e) => UserItem.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<UserItem> createUser({
    required String username,
    required String password,
    required String role,
    String? nama,
  }) async {
    final data = await _api.post('/users', body: {
      'username': username,
      'password': password,
      'role': role,
      if (nama != null && nama.isNotEmpty) 'nama': nama,
    });
    return UserItem.fromJson(data);
  }

  Future<UserItem> updateUser(String userId, Map<String, dynamic> body) async {
    final data = await _api.put('/users/$userId', body: body);
    return UserItem.fromJson(data);
  }

  Future<void> deleteUser(String userId) async {
    await _api.delete('/users/$userId');
  }

  Future<List<SyncError>> getSyncErrors() async {
    final data = await _api.get('/products/sync/errors');
    return (data as List).map((e) => SyncError.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getImportLogs() async {
    final data = await _api.get('/products/import-logs');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<void> clearImportErrors() async {
    await _api.delete('/products/import-errors');
  }

  Future<Map<String, int>> getDashboardStats() async {
    // Use the server-side /products/stats endpoint so the count is never
    // limited by a client-side 50-order window.
    final data = await _api.get('/products/stats');
    return {
      'total_orders': data['total_orders'] ?? 0,
      'pending_orders': data['pending_orders'] ?? 0,
      'approved_orders': data['approved_orders'] ?? 0,
      'rejected_orders': data['rejected_orders'] ?? 0,
      'expired_orders': data['expired_orders'] ?? 0,
      'cancelled_orders': data['cancelled_orders'] ?? 0,
      'total_products': data['total_products'] ?? 0,
      'needs_review': data['needs_review'] ?? 0,
    };
  }
}
