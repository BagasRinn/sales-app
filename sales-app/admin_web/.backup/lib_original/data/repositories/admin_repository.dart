import 'package:dio/dio.dart';

import '../../core/datetime_utils.dart';
import '../repositories/api_service.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/sync_result.dart';
import '../models/customer.dart';
import '../models/customer_submission.dart';
import '../models/sales_user.dart';
import '../models/sales_assignment.dart';
import '../models/user_item.dart';
import '../models/sales_performance.dart';
import '../models/sales_target.dart';
import '../models/bulletin.dart';
import '../models/branch_report.dart';
import '../models/supplier_target.dart';
import '../models/supplier_performance.dart';
import '../models/supplier.dart';

class AdminRepository {
  final ApiService _api;

  AdminRepository(this._api);

  Future<void> login(String username, String password) async {
    final resp = await _api.post(
      '/auth/login',
      body: {'username': username, 'password': password},
    );
    _api.setTokens(
      access: resp['access_token'],
      refresh: resp['refresh_token'],
    );
    // Returns full auth response for caller to extract branch/role
    return resp;
  }

  /// Returns the raw login response data (caller uses for branch/role info).
  Future<Map<String, dynamic>> loginFull(
    String username,
    String password,
  ) async {
    final resp = await _api.post(
      '/auth/login',
      body: {'username': username, 'password': password},
    );
    _api.setTokens(
      access: resp['access_token'],
      refresh: resp['refresh_token'],
    );
    return resp as Map<String, dynamic>;
  }

  void setTokens(String access, String refresh) =>
      _api.setTokens(access: access, refresh: refresh);
  void clearTokens() => _api.clearTokens();
  bool get hasToken => _api.hasToken;

  Future<List<Order>> getPendingOrders({
    String? search,
    CancelToken? cancelToken,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/orders/pending$qs', cancelToken: cancelToken);
    return (data as List).map((e) => Order.fromJson(e)).toList();
  }

  /// Ambil order untuk sales/branch tertentu (untuk popup detail di dashboard).
  /// [salesId] nullable — kalau null, tidak filter per sales (dipakai oleh
  /// "Total Semua Sales" card untuk lihat gabungan semua sales dalam branch).
  /// [branch] nullable — kalau di-set, hanya return order dari branch tsb
  /// (dipakai oleh "Masing-masing Cabang" card untuk MANAGER drill-down).
  /// Total (orders/amount/discount/up price) dihitung server untuk SELURUH
  /// hasil filter — list yang dikirim tetap dibatasi [limit], jadi summary
  /// popup tidak ikut terpotong.
  Future<
    ({
      List<Order> orders,
      int total,
      int totalAmount,
      int totalDiscount,
      int totalUpPrice,
    })
  >
  getOrdersBySales({
    String? salesId,
    String? branch,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
    int skip = 0,
    int limit = 100,
    CancelToken? cancelToken,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (salesId != null && salesId.isNotEmpty) params['sales_id'] = salesId;
    if (branch != null && branch.isNotEmpty) params['branch'] = branch;
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (dateFrom != null) params['date_from'] = witaDateStr(dateFrom);
    if (dateTo != null) params['date_to'] = witaDateStr(dateTo);
    final qs = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final response = await _api.dio.get<dynamic>(
      '/orders$qs',
      options: Options(responseType: ResponseType.json),
    );
    final body = response.data as Map<String, dynamic>;
    final ordersList = body['orders'] as List? ?? const [];
    return (
      orders: ordersList
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: (body['total'] as num?)?.toInt() ?? ordersList.length,
      totalAmount: (body['total_amount'] as num?)?.toInt() ?? 0,
      totalDiscount: (body['total_discount'] as num?)?.toInt() ?? 0,
      totalUpPrice: (body['total_up_price'] as num?)?.toInt() ?? 0,
    );
  }

  /// Ambil order dengan pagination — pakai Dio langsung agar bisa akses
  /// response.headers (X-Total-Count) dan body `{orders, total}`.
  Future<({List<Order> orders, int total})> getAllOrdersPaginated({
    String? status,
    String? search,
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
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (dateFrom != null) params['date_from'] = witaDateStr(dateFrom);
    if (dateTo != null) params['date_to'] = witaDateStr(dateTo);
    final qs = '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final response = await _api.dio.get<dynamic>(
      '/orders$qs',
      options: Options(responseType: ResponseType.json),
    );
    final body = response.data as Map<String, dynamic>;
    final ordersList = body['orders'] as List? ?? body as List;
    final orders = ordersList
        .map((e) => Order.fromJson(e as Map<String, dynamic>))
        .toList();
    final total = (body['total'] as num?)?.toInt() ?? orders.length;
    return (orders: orders, total: total);
  }

  Future<Order> getOrderDetail(String orderId) async {
    final data = await _api.get('/orders/$orderId');
    return Order.fromJson(data);
  }

  Future<void> approveOrder(String orderId) async {
    await _api.post('/orders/$orderId/approve');
  }

  Future<void> rejectOrder(String orderId, {String? rejectReason}) async {
    final body = <String, dynamic>{};
    if (rejectReason != null && rejectReason.isNotEmpty) {
      body['reject_reason'] = rejectReason;
    }
    await _api.post('/orders/$orderId/reject', body: body);
  }

  /// Update diskon per item — admin only, hanya untuk pesanan PENDING.
  Future<Order> updateOrderDiscounts(
    String orderId, {
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _api.put(
      '/orders/$orderId/discounts',
      body: {'items': items},
    );
    return Order.fromJson(data);
  }

  /// Batalkan 1 atau lebih item dari order PENDING. Admin wajib isi reason.
  /// Returns Order terbaru (dengan cancelled_items terbaru).
  Future<Order> cancelOrderItems(
    String orderId, {
    required List<Map<String, dynamic>> items,
  }) async {
    final data = await _api.put(
      '/orders/$orderId/cancel-items',
      body: {'items': items},
    );
    return Order.fromJson(data);
  }

  /// Download laporan harian sebagai bytes Excel. Caller yang handle
  /// blob URL / file save (browser download di web).
  /// `?detail=true` opt-in ke XLSX binary (default endpoint = JSON summary).
  Future<List<int>> downloadDailyReport({
    required DateTime date,
    List<String> statuses = const ['APPROVED'],
  }) async {
    final dateStr = witaDateStr(date);
    final qs = '?date=$dateStr&status=${statuses.join(',')}&detail=true';
    // Ambil raw bytes — pakai helper Dio langsung agar bypass deserialization JSON.
    final dio = _api.dio;
    final response = await dio.get<List<int>>(
      '/reports/daily$qs',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// Download laporan periode (rentang tanggal) sebagai bytes Excel.
  /// `?detail=true` opt-in ke XLSX binary (default endpoint = JSON summary).
  Future<List<int>> downloadPeriodReport({
    required DateTime startDate,
    required DateTime endDate,
    List<String> statuses = const ['APPROVED'],
  }) async {
    final startStr = witaDateStr(startDate);
    final endStr = witaDateStr(endDate);
    final qs =
        '?start_date=$startStr&end_date=$endStr&status=${statuses.join(',')}&detail=true';
    final dio = _api.dio;
    final response = await dio.get<List<int>>(
      '/reports/period$qs',
      options: Options(responseType: ResponseType.bytes),
    );
    return response.data ?? [];
  }

  /// Get summary agregat laporan (JSON, pure SQL aggregation).
  /// Pakai ini untuk display dashboard — tidak download XLSX.
  /// Range validasi: end >= start, max 365 hari (sesuai backend).
  Future<Map<String, dynamic>> getReportSummary({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final startStr = witaDateStr(startDate);
    final endStr = witaDateStr(endDate);
    final data = await _api.get(
      '/reports/summary?start_date=$startStr&end_date=$endStr',
    );
    return data as Map<String, dynamic>;
  }

  Future<List<Product>> getProducts({
    int page = 0,
    int limit = 20,
    String? search,
    String? supplier,
    String? status,
    String? orderType,
    CancelToken? cancelToken,
  }) async {
    final queryParams = {
      'skip': (page * limit).toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (status != null && status.isNotEmpty) 'status': status,
      if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final data = await _api.get(
      '/products?$queryString',
      cancelToken: cancelToken,
    );
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<String>> getSupplierList() async {
    final data = await _api.get('/products/supplier');
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<int> getProductCount({
    String? search,
    String? supplier,
    String? status,
    String? orderType,
    CancelToken? cancelToken,
  }) async {
    final queryParams = {
      if (search != null && search.isNotEmpty) 'search': search,
      if (supplier != null && supplier.isNotEmpty) 'supplier': supplier,
      if (status != null && status.isNotEmpty) 'status': status,
      if (orderType != null && orderType.isNotEmpty) 'order_type': orderType,
    };
    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get(
      '/products/count$queryString',
      cancelToken: cancelToken,
    );
    return data['total'] as int;
  }

  Future<Product> getProduct(String productId) async {
    final data = await _api.get('/products/$productId');
    return Product.fromJson(data);
  }

  Future<void> overrideStock(String productId, int stokSistem) async {
    await _api.put(
      '/products/$productId/stock',
      body: {'stok_sistem': stokSistem},
    );
  }

  /// Partial update produk (kategori/satuan/nama_supplier/order_type) — admin only.
  /// Field yang null di body akan di-skip server-side.
  Future<Product> updateProduct(
    String productId, {
    String? kategori,
    String? satuan,
    String? namaSupplier,
    String? orderType,
  }) async {
    final body = <String, dynamic>{};
    if (kategori != null) body['kategori'] = kategori;
    if (satuan != null) body['satuan'] = satuan;
    if (namaSupplier != null) body['nama_supplier'] = namaSupplier;
    if (orderType != null) body['order_type'] = orderType;

    final data = await _api.put('/products/$productId', body: body);
    return Product.fromJson(data);
  }

  Future<void> deleteProduct(String productId) async {
    await _api.delete('/products/$productId');
  }

  Future<SyncResult> syncProducts() async {
    final data = await _api.post('/products/sync');
    return SyncResult.fromJson(data);
  }

  Future<SyncResult> importExcel(List<int> fileBytes, String fileName) async {
    final data = await _api.postFile(
      '/products/import-excel',
      fileBytes,
      fileName,
    );
    return SyncResult.fromJson(data);
  }

  Future<SyncResult> importCustomersExcel(
    List<int> fileBytes,
    String fileName,
  ) async {
    final data = await _api.postFile(
      '/customers/import-excel',
      fileBytes,
      fileName,
    );
    return SyncResult.fromJson(data);
  }

  Future<List<Customer>> getCustomers({
    int page = 0,
    int limit = 20,
    String? search,
    CancelToken? cancelToken,
  }) async {
    final queryParams = {
      'skip': (page * limit).toString(),
      'limit': limit.toString(),
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    final data = await _api.get(
      '/customers?$queryString',
      cancelToken: cancelToken,
    );
    return (data as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> getCustomerCount({
    String? search,
    CancelToken? cancelToken,
  }) async {
    final queryParams = {
      if (search != null && search.isNotEmpty) 'search': search,
    };
    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get(
      '/customers/count$queryString',
      cancelToken: cancelToken,
    );
    return data['total'] as int;
  }

  Future<Customer> getCustomer(String customerId) async {
    final data = await _api.get('/customers/$customerId');
    return Customer.fromJson(data);
  }

  Future<Customer> updateCustomer(
    String customerId,
    Map<String, dynamic> body,
  ) async {
    final data = await _api.put('/customers/$customerId', body: body);
    return Customer.fromJson(data);
  }

  Future<void> deleteCustomer(String customerId) async {
    await _api.delete('/customers/$customerId');
  }

  // ===== Customer Submissions =====

  Future<List<CustomerSubmission>> getCustomerSubmissions({
    String? status,
  }) async {
    final queryString = (status != null && status.isNotEmpty)
        ? '?status=${Uri.encodeComponent(status)}'
        : '';
    final data = await _api.get('/customer-submissions$queryString');
    return (data as List)
        .map((e) => CustomerSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CustomerSubmission> getCustomerSubmissionDetail(String id) async {
    final data = await _api.get('/customer-submissions/$id');
    return CustomerSubmission.fromJson(data);
  }

  /// Approve submission. `kode` wajib (admin input manual). nama_toko & alamat optional override.
  /// Return Map {submission: ..., customer: ...} dari backend.
  Future<Map<String, dynamic>> approveCustomerSubmission(
    String submissionId, {
    required String kode,
    String? namaToko,
    String? alamat,
  }) async {
    final body = <String, dynamic>{'kode': kode};
    if (namaToko != null && namaToko.isNotEmpty) body['nama_toko'] = namaToko;
    if (alamat != null && alamat.isNotEmpty) body['alamat'] = alamat;
    final data = await _api.post(
      '/customer-submissions/$submissionId/approve',
      body: body,
    );
    return data as Map<String, dynamic>;
  }

  Future<CustomerSubmission> rejectCustomerSubmission(
    String submissionId, {
    String? rejectReason,
  }) async {
    final body = <String, dynamic>{};
    if (rejectReason != null && rejectReason.isNotEmpty) {
      body['reject_reason'] = rejectReason;
    }
    final data = await _api.post(
      '/customer-submissions/$submissionId/reject',
      body: body,
    );
    return CustomerSubmission.fromJson(data);
  }

  Future<List<SalesUser>> listSalesUsers() async {
    final data = await _api.get('/users/sales');
    return (data as List)
        .map((e) => SalesUser.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Assignment management — endpoint baru untuk tab "Penugasan Sales".
  Future<List<SalesAssignment>> getCustomerAssignments(
    String customerId,
  ) async {
    final data = await _api.get('/customers/$customerId/assignments');
    return (data as List)
        .map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SalesAssignment>> putCustomerAssignments(
    String customerId,
    List<String> salesIds,
  ) async {
    final data = await _api.put(
      '/customers/$customerId/assignments',
      body: {'sales_ids': salesIds},
    );
    return (data as List)
        .map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<Customer>> getSalesCustomers(String salesId) async {
    final data = await _api.get('/sales/$salesId/customers');
    return (data as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Area-based assignment — list area dengan sales yang di-assign.
  Future<List<Map<String, dynamic>>> getAreaAssignments() async {
    final data = await _api.get('/sales/area-assignments');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<List<SalesAssignment>> getAreaAssignmentDetail(String kodeArea) async {
    final data = await _api.get('/sales/area-assignments/$kodeArea');
    return (data as List)
        .map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SalesAssignment>> putAreaAssignment(
    String kodeArea,
    List<String> salesIds,
  ) async {
    final data = await _api.put(
      '/sales/area-assignments/$kodeArea',
      body: {'sales_ids': salesIds},
    );
    return (data as List)
        .map((e) => SalesAssignment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<UserItem>> getUsers({String? role, String? search}) async {
    final params = <String, String>{};
    if (role != null && role.isNotEmpty) params['role'] = role;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/users$qs');
    return (data as List)
        .map((e) => UserItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<UserItem> createUser({
    required String username,
    required String password,
    required String role,
    String? nama,
    String? branch,
  }) async {
    final data = await _api.post(
      '/users',
      body: {
        'username': username,
        'password': password,
        'role': role,
        if (nama != null && nama.isNotEmpty) 'nama': nama,
        if (branch != null && branch.isNotEmpty) 'branch': branch,
      },
    );
    return UserItem.fromJson(data);
  }

  Future<UserItem> updateUser(String userId, Map<String, dynamic> body) async {
    final data = await _api.put('/users/$userId', body: body);
    return UserItem.fromJson(data);
  }

  // Soft-delete User dihapus: fitur nonaktifkan (is_active=false) sudah cukup
  // untuk memblokir akses user. Hindari 2 fitur dengan tujuan yang sama.
  // Future<void> deleteUser(String userId) async {
  //   await _api.delete('/users/$userId');
  // }

  /// Ganti password user yang sedang login. Endpoint invalidate semua sesi,
  /// caller wajib clear storage & navigate ke LoginScreen.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    await _api.post(
      '/auth/change-password',
      body: {'old_password': oldPassword, 'new_password': newPassword},
    );
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

  /// Per-product monthly 'terjual' stats.
  /// [yearMonth] format: 'YYYY-MM' (e.g. '2026-10'). Null = current month (server-side).
  /// Returns list of {product_id, branch, nama_barang, stok_sistem, nama_supplier, terjual}.
  /// `terjual` = total qty approved (moved into stok_diterima) in the given month.
  /// Survives product import — import resets are logged with negative delta and
  /// excluded from the sum.
  Future<List<Map<String, dynamic>>> getProductSalesStats({
    String? yearMonth,
  }) async {
    final qs = (yearMonth != null && yearMonth.isNotEmpty)
        ? '?year_month=${Uri.encodeComponent(yearMonth)}'
        : '';
    final data = await _api.get('/products/sales-stats$qs');
    return (data as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, int>> getDashboardStats({
    DateTime? date,
    CancelToken? cancelToken,
  }) async {
    // Use the server-side /products/stats endpoint so the count is never
    // limited by a client-side 50-order window.
    final qs = date != null ? '?date=${witaDateStr(date)}' : '';
    final data = await _api.get(
      '/products/stats$qs',
      cancelToken: cancelToken,
      receiveTimeout: const Duration(seconds: 30),
    );
    return {
      'total_orders': data['total_orders'] ?? 0,
      'pending_orders': data['pending_orders'] ?? 0,
      'approved_orders': data['approved_orders'] ?? 0,
      'rejected_orders': data['rejected_orders'] ?? 0,
      'expired_orders': data['expired_orders'] ?? 0,
      'cancelled_orders': data['cancelled_orders'] ?? 0,
      'total_products': data['total_products'] ?? 0,
      'total_customers': data['total_customers'] ?? 0,
      'needs_review': data['needs_review'] ?? 0,
    };
  }

  // ===== Sales Performance =====
  Future<List<SalesPerformance>> getSalesPerformance({
    required DateTime fromDate,
    required DateTime toDate,
  }) async {
    final fromStr = witaDateStr(fromDate);
    final toStr = witaDateStr(toDate);
    final qs = '?from_date=$fromStr&to_date=$toStr';
    final data = await _api.get('/reports/sales-performance$qs');
    final list = data['sales'] as List? ?? [];
    return list
        .map((e) => SalesPerformance.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Dashboard breakdown: MTD + Today for APPROVED / PENDING / REJECTED per sales.
  /// Heavy aggregation — give the DB 60s to respond (vs the default 10s).
  Future<List<SalesPerformanceDashboardItem>>
  getSalesPerformanceDashboard() async {
    final data = await _api.get(
      '/reports/sales-performance/dashboard',
      receiveTimeout: const Duration(seconds: 60),
    );
    final list = data['sales'] as List? ?? [];
    return list
        .map(
          (e) =>
              SalesPerformanceDashboardItem.fromJson(e as Map<String, dynamic>),
        )
        .toList();
  }

  // ===== Sales Targets =====
  Future<List<SalesTarget>> getSalesTargets({String? period}) async {
    final qs = period != null ? '?period=${Uri.encodeComponent(period)}' : '';
    final data = await _api.get('/sales-targets$qs');
    return (data as List)
        .map((e) => SalesTarget.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SalesTarget> updateSalesTarget({
    required String userId,
    required String period,
    required String targetType,
    required int targetValue,
    required int incentiveAmount,
  }) async {
    final data = await _api.put(
      '/sales-targets/$userId',
      body: {
        'period': period,
        'target_type': targetType,
        'target_value': targetValue,
        'incentive_amount': incentiveAmount,
      },
    );
    return SalesTarget.fromJson(data);
  }

  // ===== Bulletins =====
  Future<List<Bulletin>> getBulletins({bool includeRead = false}) async {
    final qs = includeRead ? '?include_read=true' : '';
    final data = await _api.get('/bulletins$qs');
    return (data as List)
        .map((e) => Bulletin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Bulletin> createBulletin({
    required String title,
    String? description,
    String? pdfUrl,
    DateTime? expireAt,
  }) async {
    final body = <String, dynamic>{'title': title};
    if (description != null && description.isNotEmpty) {
      body['description'] = description;
    }
    if (pdfUrl != null && pdfUrl.isNotEmpty) body['pdf_url'] = pdfUrl;
    if (expireAt != null) body['expire_at'] = witaDateStr(expireAt);
    final data = await _api.post('/bulletins', body: body);
    return Bulletin.fromJson(data as Map<String, dynamic>);
  }

  Future<Bulletin> updateBulletin(
    String id, {
    String? title,
    String? description,
    String? pdfUrl,
    DateTime? expireAt,
  }) async {
    final body = <String, dynamic>{};
    if (title != null) body['title'] = title;
    if (description != null) body['description'] = description;
    if (pdfUrl != null) body['pdf_url'] = pdfUrl;
    if (expireAt != null) {
      body['expire_at'] = witaDateStr(expireAt);
    } else {
      // Allow clearing expiration
      body['expire_at'] = null;
    }
    final data = await _api.put('/bulletins/$id', body: body);
    return Bulletin.fromJson(data as Map<String, dynamic>);
  }

  Future<void> deleteBulletin(String id) async {
    await _api.delete('/bulletins/$id');
  }

  Future<String> uploadBulletinPdf(List<int> fileBytes, String fileName) async {
    final data = await _api.postFile(
      '/bulletins/upload-pdf',
      fileBytes,
      fileName,
    );
    return data['pdf_url'] as String;
  }

  // ===== Cross-Branch Reports (global MANAGER only) =====
  Future<List<BranchSalesSummary>> getCrossBranchSalesSummary() async {
    final data = await _api.get(
      '/reports/cross-branch/sales-summary',
      receiveTimeout: const Duration(seconds: 60),
    );
    final list = data['branches'] as List? ?? [];
    return list
        .map((e) => BranchSalesSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<BranchStockSummary>> getCrossBranchStockSummary() async {
    final data = await _api.get(
      '/reports/cross-branch/stock-summary',
      receiveTimeout: const Duration(seconds: 60),
    );
    final list = data['branches'] as List? ?? [];
    return list
        .map((e) => BranchStockSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ===== Supplier Performance (KPI per Supplier — Performa Sales) =====
  /// Monthly KPI per supplier: revenue vs target, with auto-rollover on
  /// the backend. [yearMonth] = 'YYYY-MM'. Null = current month (server).
  /// [branch] = filter cabang (MANAGER only); null = semua cabang.
  /// The endpoint batches target lookups but can still take a few seconds
  /// on a remote DB, so use a 60s receive timeout (vs the default 10s).
  Future<List<SupplierPerformanceRow>> getSupplierPerformance({
    String? yearMonth,
    String? branch,
  }) async {
    final params = <String, String>{};
    if (yearMonth != null && yearMonth.isNotEmpty) {
      params['year_month'] = yearMonth;
    }
    if (branch != null && branch.isNotEmpty) params['branch'] = branch;
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final data = await _api.get(
      '/reports/supplier-performance$qs',
      receiveTimeout: const Duration(seconds: 60),
    );
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(SupplierPerformanceRow.fromJson)
        .toList();
  }

  /// Active branches — for the MANAGER branch picker in Performa Sales.
  Future<List<BranchOption>> getBranches() async {
    final data = await _api.get('/branches');
    return (data as List)
        .cast<Map<String, dynamic>>()
        .map(BranchOption.fromJson)
        .toList();
  }

  /// Upsert the target value for a (branch, supplier, period) triple.
  /// Restricted to SUPERVISOR/MANAGER on the backend.
  Future<SupplierTarget> updateSupplierTarget({
    required String branch,
    required String supplierName,
    required String period,
    required int targetValue,
  }) async {
    final path =
        '/supplier-targets/'
        '${Uri.encodeComponent(branch)}/'
        '${Uri.encodeComponent(supplierName)}/'
        '${Uri.encodeComponent(period)}';
    final data = await _api.put(path, body: {'target_value': targetValue});
    return SupplierTarget.fromJson(data as Map<String, dynamic>);
  }

  // --- Supplier management (active/inactive) ---

  /// Fetch all suppliers. Pass [active] to filter by is_active.
  Future<List<Supplier>> getSuppliers({bool? active}) async {
    final params = <String, String>{};
    if (active != null) params['active'] = active.toString();
    final qs = params.isEmpty
        ? ''
        : '?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/suppliers$qs');
    return (data as List)
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Create a new supplier. MANAGER only on the backend.
  /// `orderType` default 'REGULER' (sesuai backend schema SupplierCreate.order_type).
  Future<Supplier> createSupplier(
    String name, {
    String orderType = 'REGULER',
  }) async {
    final data = await _api.post(
      '/suppliers',
      body: {'name': name, 'order_type': orderType},
    );
    return Supplier.fromJson(data as Map<String, dynamic>);
  }

  /// Toggle a supplier's is_active. MANAGER only on the backend.
  Future<Supplier> updateSupplierActive(String name, bool isActive) async {
    final data = await _api.patch(
      '/suppliers/${Uri.encodeComponent(name)}/active',
      body: {'is_active': isActive},
    );
    return Supplier.fromJson(data as Map<String, dynamic>);
  }

  /// Update supplier's order_type (REGULER/4P). MANAGER only.
  /// Backend akan cascade ke semua products di supplier ini.
  Future<Supplier> updateSupplierOrderType(
    String name,
    String orderType,
  ) async {
    final data = await _api.patch(
      '/suppliers/${Uri.encodeComponent(name)}/order-type',
      body: {'order_type': orderType},
    );
    return Supplier.fromJson(data as Map<String, dynamic>);
  }
}
