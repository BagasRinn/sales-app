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

  Future<List<Order>> getAllOrders({String? status}) async {
    final data = await _api.get('/orders${status != null ? '?status=$status' : ''}');
    return (data as List).map((e) => Order.fromJson(e)).toList();
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
