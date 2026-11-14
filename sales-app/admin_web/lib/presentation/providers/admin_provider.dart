import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/models/sync_result.dart';
import '../../data/models/customer.dart';
import '../../data/models/customer_submission.dart';
import '../../data/models/sales_user.dart';
import '../../data/models/sales_assignment.dart';
import '../../data/models/user_item.dart';
import '../../data/models/sales_performance.dart';
import '../../data/models/sales_target.dart';
import '../../data/models/bulletin.dart';
import '../widgets/analytics/sales_analytics_models.dart';
import '../../data/models/branch_report.dart';
import '../../data/models/supplier_performance.dart';
import '../../data/models/supplier.dart';
import '../../core/api_exception.dart';
import '../../core/config.dart';

enum AdminState { initial, loading, loaded, error }

/// Cache durations
class CacheConfig {
  static const pendingOrders = Duration(minutes: 1);
  static const dashboardStats = Duration(minutes: 5);
  static const customerSubmissions = Duration(minutes: 2);
  static const customers = Duration(minutes: 5);
  static const products = Duration(minutes: 5);
  static const suppliers = Duration(minutes: 10);
  static const salesPerformance = Duration(minutes: 5);
  static const bulletins = Duration(minutes: 10);
  static const users = Duration(minutes: 10);
  static const orders = Duration(minutes: 2);
  static const importedSales = Duration(minutes: 5);
}

/// In-memory summary cache entry. The version is the authoritative freshness
/// signal; [fetchedAt] is only used for instant display/fallback within the
/// 5-minute window.
class _ImportedSalesCacheEntry {
  final Map<String, dynamic> data;
  final int version;
  final String scope;
  final DateTime fetchedAt;

  const _ImportedSalesCacheEntry({
    required this.data,
    required this.version,
    required this.scope,
    required this.fetchedAt,
  });
}

class AdminProvider extends ChangeNotifier with WidgetsBindingObserver {
  final AdminRepository _repo;

  AdminRepository get repository => _repo;

  AdminState _state = AdminState.initial;
  String? _errorMessage;

  List<Order> _pendingOrders = [];
  List<Order> _allOrders = [];
  List<Order> _draftOrders = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<CustomerSubmission> _customerSubmissions = [];
  String? _customerSubmissionsStatus;
  SyncResult? _lastSyncResult;
  Map<String, dynamic>? _importedSalesSummary;
  bool _importedSalesLoading = false;
  String? _importedSalesError;
  Map<String, dynamic>? _salesImportResult;
  Map<String, dynamic>? _salesReturnImportResult;
  Map<String, dynamic>? _salesTargetImportResult;

  /// Imported-sales version/cache state.
  /// Key = `month|scope|limit|include`. A version match means the cached
  /// payload is still current, so the summary request is skipped entirely.
  String? _importedSalesMonth;
  String? _importedSalesScope;
  int _importedSalesVersion = 0;
  int _importedSalesLimit = 10;
  int _importedSalesRangeMonths = 1;
  int _importedSalesComparisonMonths = 1;

  /// Rata-rata omzet N bulan sebelum bulan terpilih (payload pembanding).
  Map<String, dynamic>? _importedSalesComparison;
  final Map<String, Map<String, dynamic>> _importedSalesComparisonCache = {};

  /// Detail dimensi pembanding: kode dimensi -> daftar SalesRankItem.
  Map<String, List<SalesRankItem>>? _importedSalesComparisonDetail;

  /// Branch the global MANAGER is currently inspecting. null = GLOBAL
  /// (all branches). Branch-scoped roles ignore this field; the backend
  /// always resolves them to their own branch.
  String? _importedSalesBranchFilter;
  final Map<String, _ImportedSalesCacheEntry> _importedSalesCache = {};
  // Guards against out-of-order responses when the user changes month/limit
  // quickly: only the newest request may write state.
  int _importedSalesRequestId = 0;
  Map<String, int> _stats = {};
  String? _loadingMessage;
  bool _hasNewPending = false;

  /// Cache timestamps
  DateTime? _pendingOrdersCacheTime;
  DateTime? _statsCacheTime;
  DateTime? _customersCacheTime;
  DateTime? _customerSubmissionsCacheTime;
  DateTime? _productsCacheTime;
  DateTime? _suppliersCacheTime;
  DateTime? _salesPerformanceCacheTime;
  DateTime? _bulletinsCacheTime;
  DateTime? _usersCacheTime;
  DateTime? _ordersCacheTime;

  /// Helper untuk check apakah cache masih valid.
  bool _isCacheValid(DateTime? cacheTime, Duration maxAge) {
    if (cacheTime == null) return false;
    return DateTime.now().difference(cacheTime) < maxAge;
  }

  // Pagination
  int _productPage = 0;
  final int _productLimit = 20;
  int _productTotal = 0;
  String _productSearch = '';

  // Customer pagination
  int _customerPage = 0;
  final int _customerLimit = 20;
  int _customerTotal = 0;
  String _customerSearch = '';

  // Pending/Draft orders pagination
  final int _pendingOrdersPage = 0;
  final int _pendingOrdersLimit = 50;
  final int _draftOrdersPage = 0;
  final int _draftOrdersLimit = 50;

  // Filters
  String? _selectedSupplier;
  String? _selectedStatus;
  String? _selectedOrderType;
  String? _orderFilter = 'APPROVED,REJECTED,CANCELLED';
  DateTime? _orderDateFrom;
  DateTime? _orderDateTo;
  String? _orderSearch;
  int _orderSkip = 0;
  int _orderLimit = 20;
  int _orderTotal = 0;

  // Debounce timer for search
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  // Timer terpisah untuk user search agar tidak konflik dengan products/customers
  // (mis. user di tab User mengetik saat auto-refresh timer tick di background).
  Timer? _userSearchDebounceTimer;

  /// Cancel token untuk request yang sedang berjalan. Saat tab/user navigasi
  /// atau loadAll() dipanggil lagi, kita cancel request sebelumnya supaya
  /// server tidak kirim response yang bakal diabaikan.
  CancelToken? _loadCancelToken;
  CancelToken _newLoadToken() {
    _loadCancelToken?.cancel('New load started');
    final token = CancelToken();
    _loadCancelToken = token;
    return token;
  }

  void cancelInFlightLoads() {
    _loadCancelToken?.cancel('Cancelled by user');
    _loadCancelToken = null;
  }

  int _activeTabIndex = 0;

  /// Set tab yang sedang aktif. Dipanggil dari dashboard saat user navigasi.
  /// loadAll() dan auto-refresh akan load data sesuai tab.
  void setActiveTab(int index) {
    _activeTabIndex = index;
  }

  // ===== Sales Performance (Manager only) =====
  List<SalesPerformance> _performanceList = [];
  DateTime? _performanceDateFrom;
  DateTime? _performanceDateTo;
  String _performanceSort = 'revenue'; // 'revenue' atau 'order_count'
  bool _performanceLoading = false;
  List<SalesTarget> _salesTargets = [];
  bool _targetsLoading = false;

  // ===== Dashboard Performance =====
  List<SalesPerformanceDashboardItem> _dashboardPerformance = [];
  bool _dashboardPerformanceLoading = false;

  // ===== Bulletins =====
  List<Bulletin> _bulletins = [];
  bool _bulletinsLoading = false;

  // ===== Supplier management =====
  List<Supplier> _suppliers = [];
  bool _suppliersLoading = false;
  String? _suppliersError;
  int _supplierPage = 0;
  final int _supplierLimit = 20;
  int _supplierTotal = 0;
  bool? _supplierActiveFilter;
  String _supplierSearch = '';

  List<Supplier> get suppliers => _suppliers;
  bool get suppliersLoading => _suppliersLoading;
  String? get suppliersError => _suppliersError;
  int get supplierPage => _supplierPage;
  int get supplierLimit => _supplierLimit;
  int get supplierTotal => _supplierTotal;
  int get supplierTotalPages => (_supplierTotal / _supplierLimit).ceil();
  bool get hasPrevSupplierPage => _supplierPage > 0;
  bool get hasNextSupplierPage => _supplierPage < supplierTotalPages - 1;

  Future<void> loadSuppliers({bool? active, String? search, int? page}) async {
    _suppliersLoading = true;
    _suppliersError = null;
    notifyListeners();
    try {
      if (active != null || search != null || page != null) {
        if (active != null) _supplierActiveFilter = active;
        if (search != null) {
          _supplierSearch = search;
          _supplierPage = 0;
        }
        if (page != null) _supplierPage = page;
      }
      final result = await _repo.getSuppliers(
        active: _supplierActiveFilter,
        search: _supplierSearch,
        skip: _supplierPage * _supplierLimit,
        limit: _supplierLimit,
      );
      _suppliers = result.suppliers;
      _supplierTotal = result.total;
      _suppliersCacheTime = DateTime.now();
    } catch (e) {
      _suppliersError = e.toString();
    } finally {
      _suppliersLoading = false;
      notifyListeners();
    }
  }

  Future<void> setSupplierActiveFilter(bool? active) async {
    _suppliersLoading = true;
    _supplierActiveFilter = active;
    _supplierPage = 0;
    notifyListeners();
    try {
      final result = await _repo.getSuppliers(
        active: active,
        search: _supplierSearch,
        skip: 0,
        limit: _supplierLimit,
      );
      _suppliers = result.suppliers;
      _supplierTotal = result.total;
      _suppliersError = null;
    } catch (e) {
      _suppliersError = e.toString();
    } finally {
      _suppliersLoading = false;
      notifyListeners();
    }
  }

  Future<void> nextSupplierPage() async {
    if (!hasNextSupplierPage) return;
    await loadSuppliers(page: _supplierPage + 1);
  }

  Future<void> prevSupplierPage() async {
    if (!hasPrevSupplierPage) return;
    await loadSuppliers(page: _supplierPage - 1);
  }

  Future<void> createSupplier(
    String name, {
    String orderType = 'REGULER',
  }) async {
    await _repo.createSupplier(name, orderType: orderType);
    await loadSuppliers();
  }

  Future<void> toggleSupplierActive(Supplier s) async {
    await _repo.updateSupplierActive(s.name, !s.isActive);
    await loadSuppliers();
  }

  Future<void> updateSupplierOrderType(Supplier s, String orderType) async {
    if (s.orderType == orderType) return;
    final updated = await _repo.updateSupplierOrderType(s.name, orderType);
    _suppliers = _suppliers.map((row) {
      return row.name == updated.name ? updated : row;
    }).toList();
    notifyListeners();
  }

  AdminProvider(this._repo);

  /// Expose repo untuk widget yang butuh akses langsung (mis. download file).
  AdminRepository get adminRepository => _repo;

  AdminState get state => _state;
  String? get errorMessage => _errorMessage;
  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get allOrders => _allOrders;
  List<Order> get draftOrders => _draftOrders;
  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<CustomerSubmission> get customerSubmissions => _customerSubmissions;
  String? get customerSubmissionsStatus => _customerSubmissionsStatus;
  int get customerSubmissionsPendingCount =>
      _customerSubmissions.where((s) => s.status == 'PENDING').length;
  SyncResult? get lastSyncResult => _lastSyncResult;
  Map<String, dynamic>? get importedSalesSummary => _importedSalesSummary;
  bool get importedSalesLoading => _importedSalesLoading;
  String? get importedSalesError => _importedSalesError;
  String? get importedSalesMonth => _importedSalesMonth;
  String? get importedSalesScope => _importedSalesScope;
  int get importedSalesVersion => _importedSalesVersion;
  int get importedSalesLimit => _importedSalesLimit;
  int get importedSalesRangeMonths => _importedSalesRangeMonths;
  int get importedSalesComparisonMonths => _importedSalesComparisonMonths;
  Map<String, dynamic>? get importedSalesComparison => _importedSalesComparison;
  Map<String, List<SalesRankItem>>? get importedSalesComparisonDetail =>
      _importedSalesComparisonDetail;
  String? get importedSalesBranchFilter => _importedSalesBranchFilter;
  Map<String, dynamic>? get salesImportResult => _salesImportResult;
  Map<String, dynamic>? get salesReturnImportResult => _salesReturnImportResult;
  Map<String, dynamic>? get salesTargetImportResult => _salesTargetImportResult;
  Map<String, int> get stats => _stats;
  String? get loadingMessage => _loadingMessage;
  bool get isLoading => _state == AdminState.loading;
  bool get hasNewPending => _hasNewPending;
  int get productPage => _productPage;
  int get productLimit => _productLimit;
  int get productTotal => _productTotal;
  int get productTotalPages => (_productTotal / _productLimit).ceil();
  bool get hasPrevProductPage => _productPage > 0;
  bool get hasNextProductPage => _productPage < productTotalPages - 1;
  String get productSearch => _productSearch;
  String? get selectedSupplier => _selectedSupplier;
  String? get selectedStatus => _selectedStatus;
  String? get selectedOrderType => _selectedOrderType;
  String? get orderFilter => _orderFilter;
  DateTime? get orderDateFrom => _orderDateFrom;
  DateTime? get orderDateTo => _orderDateTo;
  String? get orderSearch => _orderSearch;
  int get orderTotal => _orderTotal;

  int get customerPage => _customerPage;
  int get customerLimit => _customerLimit;
  int get customerTotal => _customerTotal;
  int get customerTotalPages => (_customerTotal / _customerLimit).ceil();
  bool get hasPrevCustomerPage => _customerPage > 0;
  bool get hasNextCustomerPage => _customerPage < customerTotalPages - 1;
  String get customerSearch => _customerSearch;

  // ===== Sales Performance =====
  List<SalesPerformance> get performanceList => _performanceList;
  DateTime? get performanceDateFrom => _performanceDateFrom;
  DateTime? get performanceDateTo => _performanceDateTo;
  String get performanceSort => _performanceSort;
  bool get performanceLoading => _performanceLoading;
  List<SalesTarget> get salesTargets => _salesTargets;
  bool get targetsLoading => _targetsLoading;
  List<SalesPerformanceDashboardItem> get dashboardPerformance =>
      _dashboardPerformance;
  bool get dashboardPerformanceLoading => _dashboardPerformanceLoading;

  // ===== Bulletins =====
  List<Bulletin> get bulletins => _bulletins;
  bool get bulletinsLoading => _bulletinsLoading;

  String _userRole = 'ADMIN';
  String get userRole => _userRole;
  bool get isAdmin => _userRole == 'ADMIN';
  bool get isManager =>
      _userRole == 'ADMIN' ||
      _userRole == 'SUPERVISOR' ||
      _userRole == 'MANAGER';
  bool get isSupervisor => _userRole == 'SUPERVISOR';

  /// MANAGER without a branch — the only role allowed to switch the
  /// imported-sales scope between GLOBAL and a single branch.
  bool get isGlobalManager =>
      _userRole == 'MANAGER' && (_userBranch == null || _userBranch!.isEmpty);

  String? _userBranch;
  String? get userBranch => _userBranch;

  void setUserRole(String role) {
    // Tidak notifyListeners: _userRole cuma dipakai loadAll() untuk skip endpoint
    // admin-only. UI pakai widget.role langsung dari DashboardScreen.
    if (_userRole != role) {
      // Role menentukan scope ringkasan penjualan (GLOBAL vs cabang).
      _importedSalesBranchFilter = null;
      invalidateImportedSalesCache(clearSummary: true);
    }
    _userRole = role;
  }

  void setUserBranch(String? branch) {
    if (_userBranch != branch) {
      // Scope changed (e.g. different session/branch): cached summaries and
      // versions belong to the old scope and must not be reused.
      _importedSalesBranchFilter = null;
      invalidateImportedSalesCache(clearSummary: true);
    }
    _userBranch = branch;
  }

  /// Track app lifecycle — hanya refresh saat balik ke foreground kalau cache expired.
  /// Ini pengganti auto-refresh interval yang boros request.
  bool _isVisible = true;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final wasVisible = _isVisible;
    _isVisible = state == AppLifecycleState.resumed;
    // Saat balik ke foreground, check apakah cache sudah expired.
    // Kalau expired, refresh data tab yang aktif.
    if (!wasVisible && _isVisible) {
      _refreshIfCacheExpired();
    }
  }

  /// Check apakah cache untuk tab aktif sudah expired. Kalau ya, fetch ulang.
  /// Ini dipanggil saat app kembali ke foreground.
  Future<void> _refreshIfCacheExpired() async {
    if (_state == AdminState.loading) return;

    bool needsRefresh = false;
    switch (_activeTabIndex) {
      case 0: // Dashboard
        needsRefresh =
            !_isCacheValid(
              _pendingOrdersCacheTime,
              CacheConfig.pendingOrders,
            ) ||
            !_isCacheValid(_statsCacheTime, CacheConfig.dashboardStats);
        break;
      case 1: // Pesanan
        needsRefresh = !_isCacheValid(_ordersCacheTime, CacheConfig.orders);
        break;
      case 2: // Toko
      case 3: // Pengajuan Customer
        needsRefresh =
            !_isCacheValid(_customersCacheTime, CacheConfig.customers) ||
            !_isCacheValid(
              _customerSubmissionsCacheTime,
              CacheConfig.customerSubmissions,
            );
        break;
      case 4: // Produk & Stok
        needsRefresh = !_isCacheValid(_productsCacheTime, CacheConfig.products);
        break;
      case 5: // Supplier
        needsRefresh = !_isCacheValid(
          _suppliersCacheTime,
          CacheConfig.suppliers,
        );
        break;
      case 7: // User
        needsRefresh = !_isCacheValid(_usersCacheTime, CacheConfig.users);
        break;
      case 8: // Performa Sales
        needsRefresh = !_isCacheValid(
          _salesPerformanceCacheTime,
          CacheConfig.salesPerformance,
        );
        break;
      case 10: // Bulletin
        needsRefresh = !_isCacheValid(
          _bulletinsCacheTime,
          CacheConfig.bulletins,
        );
        break;
      case 11: // Data Penjualan (imported sales)
        // A version probe is tiny; always check on resume/focus. The summary
        // itself is only re-downloaded when the version changed.
        // Gate by the feature flag: when it is off, index 11 belongs to a
        // different page (e.g. cross-branch) and must not trigger this probe.
        needsRefresh = AppConfig.enableImportedSales;
        break;
    }

    if (needsRefresh) {
      await loadAll();
    }
  }

  /// Invalidate cache untuk tab tertentu. Dipanggil setelah operasi write
  /// (approve, reject, create, update, delete) supaya data fresh setelahnya.
  void invalidateTabCache(int tabIndex) {
    switch (tabIndex) {
      case 0: // Dashboard
        _pendingOrdersCacheTime = null;
        _statsCacheTime = null;
        _salesPerformanceCacheTime = null;
        break;
      case 1: // Pesanan
        _ordersCacheTime = null;
        _pendingOrdersCacheTime = null;
        break;
      case 2: // Toko
        _customersCacheTime = null;
        break;
      case 3: // Pengajuan Customer
        _customerSubmissionsCacheTime = null;
        break;
      case 4: // Produk & Stok
        _productsCacheTime = null;
        _statsCacheTime = null;
        break;
      case 5: // Supplier
        _suppliersCacheTime = null;
        break;
    }
  }

  /// Invalidate semua cache. Dipakai saat user manual refresh.
  void invalidateAllCache() {
    _pendingOrdersCacheTime = null;
    _statsCacheTime = null;
    _customersCacheTime = null;
    _customerSubmissionsCacheTime = null;
    _productsCacheTime = null;
    _suppliersCacheTime = null;
    _salesPerformanceCacheTime = null;
    _bulletinsCacheTime = null;
    _usersCacheTime = null;
    _ordersCacheTime = null;
    invalidateImportedSalesCache();
  }

  /// Drop cached imported-sales summaries. Called after an import and when
  /// the user's branch/scope changes.
  void invalidateImportedSalesCache({bool clearSummary = false}) {
    // Discard any in-flight response so it cannot repopulate stale data.
    _importedSalesRequestId++;
    _importedSalesCache.clear();
    if (clearSummary) {
      _importedSalesSummary = null;
      _importedSalesVersion = 0;
      _importedSalesScope = null;
    }
  }

  /// Clear the "new pending" badge after user sees it.
  void clearNewPendingBadge() {
    _hasNewPending = false;
    notifyListeners();
  }

  void _setLoading(bool loading, [String? msg]) {
    _state = loading ? AdminState.loading : AdminState.loaded;
    _loadingMessage = msg;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadPendingOrders({String? search}) async {
    try {
      _pendingOrders = await _repo.getPendingOrders(
        search: search,
        skip: _pendingOrdersPage * _pendingOrdersLimit,
        limit: _pendingOrdersLimit,
      );
      _pendingOrdersCacheTime = DateTime.now(); // Update cache timestamp
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> loadAllOrders({
    String? status,
    String? search,
    DateTime? dateFrom,
    DateTime? dateTo,
    int skip = 0,
    int limit = 20,
  }) async {
    _orderFilter = status;
    _orderSearch = search;
    _orderDateFrom = dateFrom;
    _orderDateTo = dateTo;
    _orderSkip = skip;
    _orderLimit = limit;
    try {
      final result = await _repo.getAllOrdersPaginated(
        status: status,
        search: search,
        dateFrom: dateFrom,
        dateTo: dateTo,
        skip: skip,
        limit: limit,
      );
      _allOrders = result.orders;
      _orderTotal = result.total;
      _ordersCacheTime = DateTime.now(); // Update cache timestamp
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  /// Load draft orders (status DRAFT)
  Future<void> loadDraftOrders() async {
    try {
      _draftOrders = await _repo.getDraftOrders(
        skip: _draftOrdersPage * _draftOrdersLimit,
        limit: _draftOrdersLimit,
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  /// Release (delete) a draft order
  Future<void> releaseDraftOrder(String id, String reason) async {
    try {
      await _repo.deleteDraftOrder(id, reason);
      // remove locally
      _draftOrders.removeWhere((o) => o.id == id);
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Delete draft order (alias used by UI)
  Future<bool> deleteDraftOrder(String orderId) async {
    _setLoading(true, 'Releasing draft...');
    try {
      await releaseDraftOrder(orderId, '');
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadProducts() async {
    try {
      final results = await Future.wait([
        _repo.getProducts(
          page: _productPage,
          limit: _productLimit,
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
          orderType: _selectedOrderType,
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
          orderType: _selectedOrderType,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
      _productsCacheTime = DateTime.now(); // Update cache timestamp
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> setSupplierFilter(String? supplier) async {
    _selectedSupplier = supplier;
    _productPage = 0;
    await loadProducts();
  }

  Future<void> setStatusFilter(String? status) async {
    _selectedStatus = status;
    _productPage = 0;
    await loadProducts();
  }

  Future<void> setOrderTypeFilter(String? orderType) async {
    _selectedOrderType = orderType;
    _productPage = 0;
    await loadProducts();
  }

  Future<void> clearAllFilters() async {
    _selectedSupplier = null;
    _selectedStatus = null;
    _selectedOrderType = null;
    _productSearch = '';
    _productPage = 0;
    _searchDebounceTimer?.cancel();
    await loadProducts();
  }

  Future<List<String>> getSupplierList() async {
    return await _repo.getSupplierList();
  }

  Future<void> searchProducts(String query) async {
    _productSearch = query;
    _productPage = 0;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () => loadProducts());
  }

  Future<void> nextProductPage() async {
    if (hasNextProductPage) {
      _productPage++;
      await loadProducts();
    }
  }

  Future<void> prevProductPage() async {
    if (hasPrevProductPage) {
      _productPage--;
      await loadProducts();
    }
  }

  Future<void> clearSearch() async {
    _productSearch = '';
    _productPage = 0;
    _searchDebounceTimer?.cancel();
    await loadProducts();
  }

  Future<void> _loadCustomers([CancelToken? cancelToken]) async {
    try {
      final results = await Future.wait([
        _repo.getCustomers(
          page: _customerPage,
          limit: _customerLimit,
          search: _customerSearch.isEmpty ? null : _customerSearch,
          cancelToken: cancelToken,
        ),
        _repo.getCustomerCount(
          search: _customerSearch.isEmpty ? null : _customerSearch,
          cancelToken: cancelToken,
        ),
      ]);
      _customers = results[0] as List<Customer>;
      _customerTotal = results[1] as int;
      _customersCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
      }
    }
  }

  Future<void> loadCustomers() async {
    try {
      await _loadCustomers();
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  Future<void> loadCustomerSubmissions({String? status}) async {
    try {
      _customerSubmissionsStatus = status;
      _customerSubmissions = await _repo.getCustomerSubmissions(status: status);
      _customerSubmissionsCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    }
    notifyListeners();
  }

  Future<CustomerSubmission> approveCustomerSubmission(
    String submissionId, {
    required String kode,
    String? namaToko,
    String? alamat,
  }) async {
    try {
      final result = await _repo.approveCustomerSubmission(
        submissionId,
        kode: kode,
        namaToko: namaToko,
        alamat: alamat,
      );
      // Refresh list supaya status update kelihatan.
      await loadCustomerSubmissions(status: _customerSubmissionsStatus);
      // Backend return {submission, customer} untuk flow normal, dan
      // {submission, customer, bareng_order} untuk bareng case. Fallback ke
      // list reload kalau response tidak punya `submission` key.
      final submissionJson = result['submission'];
      if (submissionJson is Map<String, dynamic>) {
        return CustomerSubmission.fromJson(submissionJson);
      }
      // Fallback: cari submission yang baru di-approve dari list yang baru di-load.
      final updated = _customerSubmissions.firstWhere(
        (s) => s.id == submissionId,
        orElse: () => throw StateError(
          'Approve response missing submission dan submission $submissionId '
          'tidak ditemukan di list refresh',
        ),
      );
      return updated;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<CustomerSubmission> rejectCustomerSubmission(
    String submissionId, {
    String? rejectReason,
  }) async {
    try {
      final updated = await _repo.rejectCustomerSubmission(
        submissionId,
        rejectReason: rejectReason,
      );
      await loadCustomerSubmissions(status: _customerSubmissionsStatus);
      return updated;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Silent variant untuk auto-refresh — tidak notify saat error, tidak set errorMessage.
  Future<void> _loadCustomerSubmissionsSilent() async {
    try {
      _customerSubmissions = await _repo.getCustomerSubmissions(
        status: _customerSubmissionsStatus,
      );
      _customerSubmissionsCacheTime = DateTime.now(); // Update cache timestamp
    } catch (_) {
      // silent
    }
  }

  Future<void> searchCustomers(String query) async {
    _customerSearch = query;
    _customerPage = 0;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(
      _searchDebounceDuration,
      () => loadCustomers(),
    );
  }

  Future<void> clearCustomerSearch() async {
    _customerSearch = '';
    _customerPage = 0;
    _searchDebounceTimer?.cancel();
    await loadCustomers();
  }

  Future<void> nextCustomerPage() async {
    if (hasNextCustomerPage) {
      _customerPage++;
      await loadCustomers();
    }
  }

  Future<void> prevCustomerPage() async {
    if (hasPrevCustomerPage) {
      _customerPage--;
      await loadCustomers();
    }
  }

  Future<Customer> getCustomerDetail(String customerId) async {
    return await _repo.getCustomer(customerId);
  }

  Future<List<SalesUser>> listSalesUsers() async {
    return await _repo.listSalesUsers();
  }

  /// Assignment management untuk tab "Penugasan Sales".
  Future<List<SalesAssignment>> getCustomerAssignments(
    String customerId,
  ) async {
    return await _repo.getCustomerAssignments(customerId);
  }

  Future<List<SalesAssignment>> putCustomerAssignments(
    String customerId,
    List<String> salesIds,
  ) async {
    _setLoading(true, 'Menyimpan penugasan...');
    try {
      final result = await _repo.putCustomerAssignments(customerId, salesIds);
      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<Customer>> getSalesCustomers(String salesId) async {
    return await _repo.getSalesCustomers(salesId);
  }

  /// Area-based assignment.
  Future<List<Map<String, dynamic>>> getAreaAssignments() async {
    return await _repo.getAreaAssignments();
  }

  Future<List<SalesAssignment>> getAreaAssignmentDetail(String kodeArea) async {
    return await _repo.getAreaAssignmentDetail(kodeArea);
  }

  Future<List<SalesAssignment>> putAreaAssignment(
    String kodeArea,
    List<String> salesIds,
  ) async {
    _setLoading(true, 'Menyimpan penugasan area...');
    try {
      final result = await _repo.putAreaAssignment(kodeArea, salesIds);
      _setLoading(false);
      return result;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<bool> updateCustomer(
    String customerId,
    Map<String, dynamic> body,
  ) async {
    _setLoading(true, 'Menyimpan perubahan...');
    try {
      await _repo.updateCustomer(customerId, body);
      await _loadCustomers();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteCustomer(String customerId) async {
    _setLoading(true, 'Menghapus toko...');
    try {
      await _repo.deleteCustomer(customerId);
      await _loadCustomers();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> createUser({
    required String username,
    required String password,
    required String role,
    String? nama,
    String? branch,
  }) async {
    _setLoading(true, 'Membuat user...');
    try {
      final newUser = await _repo.createUser(
        username: username,
        password: password,
        role: role,
        nama: nama,
        branch: branch,
      );
      _users = [..._users, newUser];
      _sortUsers();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> body) async {
    _setLoading(true, 'Menyimpan perubahan...');
    try {
      final updated = await _repo.updateUser(userId, body);
      _users = _users.map((u) => u.id == updated.id ? updated : u).toList();
      _sortUsers();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  List<UserItem> _users = [];
  String _userRoleFilter = '';
  String _userSearch = '';

  List<UserItem> get users => _users;
  String get userRoleFilter => _userRoleFilter;
  String get userSearch => _userSearch;

  /// Aktif di atas, nonaktif di bawah. Tiap group diurutkan A-Z by nama (fallback ke username).
  int _compareUsers(UserItem a, UserItem b) {
    if (a.isActive != b.isActive) {
      return a.isActive ? -1 : 1;
    }
    final aKey = (a.nama != null && a.nama!.isNotEmpty) ? a.nama! : a.username;
    final bKey = (b.nama != null && b.nama!.isNotEmpty) ? b.nama! : b.username;
    return aKey.toLowerCase().compareTo(bKey.toLowerCase());
  }

  void _sortUsers() => _users.sort(_compareUsers);

  Future<void> loadUsers({String? role, String? search}) async {
    if (role != null) _userRoleFilter = role;
    if (search != null) _userSearch = search;
    try {
      _users = await _repo.getUsers(
        role: _userRoleFilter.isEmpty ? null : _userRoleFilter,
        search: _userSearch.isEmpty ? null : _userSearch,
      );
      _usersCacheTime = DateTime.now(); // Update cache timestamp
      _sortUsers();
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
    }
  }

  /// Debounced user search — pakai pattern yang sama dengan searchProducts
  /// dan searchCustomers supaya tiap ketukan tidak firing 1 HTTP request.
  void searchUsers(String query) {
    _userSearch = query;
    _userSearchDebounceTimer?.cancel();
    _userSearchDebounceTimer = Timer(_searchDebounceDuration, () {
      loadUsers(search: query);
    });
  }

  Future<void> _loadStats({DateTime? date, CancelToken? cancelToken}) async {
    try {
      // Default: hitung berdasarkan tanggal local perangkat (WIB/WITA/WIT).
      // bukan total sepanjang masa di database.
      final effectiveDate = date ?? _todayWita();
      _stats = await _repo.getDashboardStats(
        date: effectiveDate,
        cancelToken: cancelToken,
      );
      _statsCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      // Tangkap SEMUA error — Dio network errors throw di luar ApiException.
      // _stats = {} default, dashboard tampil 0 bukan blank/crash.
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
      }
    }
  }

  DateTime _todayWita() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> loadAll({DateTime? date, bool forceRefresh = false}) async {
    final tab = _activeTabIndex;

    // Check cache validity if not forcing refresh
    if (!forceRefresh) {
      bool cacheValid = false;
      switch (tab) {
        case 0: // Dashboard
          cacheValid =
              _isCacheValid(
                _pendingOrdersCacheTime,
                CacheConfig.pendingOrders,
              ) &&
              _isCacheValid(_statsCacheTime, CacheConfig.dashboardStats);
          break;
        case 1: // Pesanan
          cacheValid = _isCacheValid(_ordersCacheTime, CacheConfig.orders);
          break;
        case 2: // Toko
          cacheValid = _isCacheValid(
            _customersCacheTime,
            CacheConfig.customers,
          );
          break;
        case 3: // Pengajuan Customer
          cacheValid = _isCacheValid(
            _customerSubmissionsCacheTime,
            CacheConfig.customerSubmissions,
          );
          break;
        case 4: // Produk & Stok
          cacheValid = _isCacheValid(_productsCacheTime, CacheConfig.products);
          break;
        case 5: // Supplier
          cacheValid = _isCacheValid(
            _suppliersCacheTime,
            CacheConfig.suppliers,
          );
          break;
        case 7: // User
          cacheValid = _isCacheValid(_usersCacheTime, CacheConfig.users);
          break;
        case 8: // Performa Sales (Manager & Supervisor)
          cacheValid = _isCacheValid(
            _salesPerformanceCacheTime,
            CacheConfig.salesPerformance,
          );
          break;
        case 10: // Bulletin (Manager & Supervisor)
          cacheValid = _isCacheValid(
            _bulletinsCacheTime,
            CacheConfig.bulletins,
          );
          break;
        case 11: // Data Penjualan (imported sales)
          // Never skip: the version probe is the freshness mechanism.
          // When the feature is disabled this index is another page.
          cacheValid = !AppConfig.enableImportedSales;
          break;
        default:
          cacheValid = false;
      }

      // If cache is valid, just mark as loaded without fetching
      if (cacheValid && _state == AdminState.loaded) {
        return;
      }
    }

    _setLoading(true, 'Memuat data...');
    final cancelToken = _newLoadToken();
    try {
      // Lazy load: hanya fetch data sesuai tab yang aktif. Tidak load
      // data tab lain di awal —irit request dan backend load.
      if (tab == 0) {
        // Dashboard: pending + stats + performance
        await Future.wait([
          _loadPendingOrders(cancelToken),
          if (isAdmin || isManager || isSupervisor)
            _loadStats(date: date, cancelToken: cancelToken),
          if (isManager || isSupervisor) _loadSalesPerformanceDashboard(),
        ]);
      } else if (tab == 1) {
        // Pesanan: orders + pending
        await Future.wait([
          _loadPendingOrders(cancelToken),
          _loadAllOrders(cancelToken),
        ]);
      } else if (tab == 2 || tab == 3) {
        // Toko / Pengajuan Customer: customers + submissions
        await Future.wait([
          _loadCustomers(cancelToken),
          _loadCustomerSubmissionsSilent(),
        ]);
      } else if (tab == 4) {
        // Produk & Stok
        await _loadProducts(cancelToken);
      } else if (tab == 7) {
        // User
        // users loaded separately by users tab itself
      } else if (tab == 11 && AppConfig.enableImportedSales) {
        // Data Penjualan: version probe + summary only if the version changed.
        await loadImportedSalesSummary(month: _importedSalesMonth);
      }
      _state = AdminState.loaded;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) return;
      _state = AdminState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  /// Manual refresh — force reload data untuk tab aktif.
  /// Dipanggil dari refresh button di dashboard.
  Future<void> refresh() async {
    await loadAll(forceRefresh: true);
  }

  Future<void> _loadSalesPerformanceDashboard() async {
    try {
      _dashboardPerformance = await _repo.getSalesPerformanceDashboard();
      _errorMessage = null;
    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e is ApiException ? e.message : e.toString();
      }
    }
  }

  Future<void> _loadPendingOrders([CancelToken? cancelToken]) async {
    try {
      _pendingOrders = await _repo.getPendingOrders(
        search: _orderSearch,
        skip: _pendingOrdersPage * _pendingOrdersLimit,
        limit: _pendingOrdersLimit,
        cancelToken: cancelToken,
      );
      _pendingOrdersCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
      }
    }
  }

  Future<void> _loadAllOrders([CancelToken? cancelToken]) async {
    try {
      final result = await _repo.getAllOrdersPaginated(
        status: _orderFilter,
        search: _orderSearch,
        dateFrom: _orderDateFrom,
        dateTo: _orderDateTo,
        skip: _orderSkip,
        limit: _orderLimit,
      );
      _allOrders = result.orders;
      _orderTotal = result.total;
      _ordersCacheTime = DateTime.now(); // Update cache timestamp
      // Jangan reset _errorMessage di sini — kalau _loadStats sukses,
      // _errorMessage sudah di-clear di sana. Kalau _loadOrders gagal,
      // _loadStats berikutnya akan overwrite kalau dia juga tidak gagal.
    } catch (e, st) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
        // Print stack trace supaya debugging lebih mudah di Flutter web.
        // ignore: avoid_print
        print('[AdminProvider] _loadAllOrders failed: $e\n$st');
      }
    }
  }

  Future<void> _loadProducts([CancelToken? cancelToken]) async {
    try {
      final results = await Future.wait([
        _repo.getProducts(
          page: _productPage,
          limit: _productLimit,
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
          orderType: _selectedOrderType,
          cancelToken: cancelToken,
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
          orderType: _selectedOrderType,
          cancelToken: cancelToken,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
      _productsCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
      }
    }
  }

  Future<bool> approveOrder(String orderId) async {
    _setLoading(true, 'Menyetujui pesanan...');
    try {
      await _repo.approveOrder(orderId);
      // Local state update — TIDAK panggil loadAll() (5 query paralel).
      // Update order di _allOrders, hapus dari _pendingOrders, decrement pending count.
      _allOrders = _allOrders.map((o) {
        if (o.id != orderId) return o;
        return o.copyWith(status: 'APPROVED');
      }).toList();
      _pendingOrders = _pendingOrders.where((o) => o.id != orderId).toList();
      if (_stats.isNotEmpty && _stats['pending_orders'] != null) {
        _stats = Map<String, int>.from(_stats);
        _stats['pending_orders'] = (_stats['pending_orders']! - 1).clamp(
          0,
          1 << 30,
        );
        _stats['approved_orders'] = (_stats['approved_orders'] ?? 0) + 1;
      }
      // Update cache timestamp after write operation
      _pendingOrdersCacheTime = DateTime.now();
      _ordersCacheTime = DateTime.now();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectOrder(String orderId, {String? rejectReason}) async {
    _setLoading(true, 'Menolak pesanan...');
    try {
      await _repo.rejectOrder(orderId, rejectReason: rejectReason);
      _allOrders = _allOrders.map((o) {
        if (o.id != orderId) return o;
        return o.copyWith(status: 'REJECTED', rejectReason: rejectReason);
      }).toList();
      _pendingOrders = _pendingOrders.where((o) => o.id != orderId).toList();
      if (_stats.isNotEmpty && _stats['pending_orders'] != null) {
        _stats = Map<String, int>.from(_stats);
        _stats['pending_orders'] = (_stats['pending_orders']! - 1).clamp(
          0,
          1 << 30,
        );
        _stats['rejected_orders'] = (_stats['rejected_orders'] ?? 0) + 1;
      }
      // Update cache timestamp after write operation
      _pendingOrdersCacheTime = DateTime.now();
      _ordersCacheTime = DateTime.now();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrderItem(
    String orderId,
    int qty,
    String reason,
    String itemId,
  ) async {
    _setLoading(true, 'Membatalkan item...');
    try {
      await _repo.cancelOrderItems(
        orderId,
        items: [
          {'item_id': itemId, 'qty': qty, 'reason': reason},
        ],
      );
      // Local state update — tambahkan entry ke cancelledItems di order tsb.
      _allOrders = _allOrders.map((o) {
        if (o.id != orderId) return o;
        final newCancelled = [
          ...o.cancelledItems,
          CancelledItem(productId: itemId, qty: qty, reason: reason),
        ];
        return o.copyWith(cancelledItems: newCancelled);
      }).toList();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> overrideStock(String productId, int stokSistem) async {
    _setLoading(true, 'Mengubah stok...');
    try {
      await _repo.overrideStock(productId, stokSistem);
      await _loadProducts();
      await _loadStats();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _setLoading(true, 'Menghapus produk...');
    try {
      await _repo.deleteProduct(productId);
      await _loadProducts();
      await _loadStats();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> syncProducts() async {
    _setLoading(true, 'Menyinkronkan data dari Excel...');
    try {
      _lastSyncResult = await _repo.syncProducts();
      await _loadProducts();
      await _loadStats();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> importExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    _setLoading(true, 'Mengimport file Excel...');
    try {
      _lastSyncResult = await _repo.importExcel(
        fileBytes,
        fileName,
        jobId: jobId,
        onSendProgress: onSendProgress,
      );
      await _loadProducts();
      await _loadStats();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> importCustomersExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    _setLoading(true, 'Mengimport data toko...');
    try {
      _lastSyncResult = await _repo.importCustomersExcel(
        fileBytes,
        fileName,
        jobId: jobId,
        onSendProgress: onSendProgress,
      );
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Poll snapshot progres import dari backend; null jika job belum terdaftar.
  Future<Map<String, dynamic>?> fetchImportProgress(String jobId) async {
    try {
      return await _repo.getImportProgress(jobId);
    } catch (_) {
      return null;
    }
  }

  /// Switch the global MANAGER branch filter for the imported-sales page.
  /// null/empty = all branches (GLOBAL). The previous payload is cleared so
  /// the UI never shows another scope's data while the new scope loads.
  void setImportedSalesBranchFilter(String? branch) {
    final normalized = (branch == null || branch.trim().isEmpty)
        ? null
        : branch.trim().toUpperCase();
    if (_importedSalesBranchFilter == normalized) return;

    _importedSalesBranchFilter = normalized;
    _importedSalesRequestId++;
    _importedSalesSummary = null;
    _importedSalesVersion = 0;
    _importedSalesScope = null;
    _importedSalesError = null;
    notifyListeners();
  }

  String _currentImportedSalesMonth() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}';
  }

  /// Scope used for cache keys before the server confirms it.
  String _resolvedSalesScope() {
    if (isGlobalManager) {
      final filter = _importedSalesBranchFilter;
      return (filter == null || filter.isEmpty) ? 'GLOBAL' : filter;
    }
    return _userBranch ?? '';
  }

  String _importedSalesCacheKey(
    String month,
    String scope,
    int limit,
    int rangeMonths,
    String include,
  ) {
    return '$month|$scope|$limit|$rangeMonths|$include';
  }

  /// Load the imported-sales summary using the version-first flow:
  ///
  /// 1. Paint the cached payload instantly (if it is inside the 5-minute
  ///    display window).
  /// 2. Probe the tiny version endpoint.
  /// 3. Download the summary only when the version differs (or no cache).
  ///
  /// A version match is authoritative even when the cache is older than
  /// 5 minutes — the TTL is a display/fallback aid, not a freshness bypass.
  Future<bool> loadImportedSalesSummary({
    String? month,
    int? limit,
    int? rangeMonths,
    bool forceRefresh = false,
  }) async {
    final targetMonth = (month == null || month.trim().isEmpty)
        ? (_importedSalesMonth ?? _currentImportedSalesMonth())
        : month.trim();
    final effectiveLimit = limit ?? _importedSalesLimit;
    final effectiveRangeMonths = rangeMonths ?? _importedSalesRangeMonths;
    const include =
        'product,sales,all_sales,customer,channel,divisi,supplier,supplier_retur,day,sales_day';

    final previousMonth = _importedSalesMonth;
    final previousScope = _importedSalesScope;
    _importedSalesMonth = targetMonth;
    _importedSalesLimit = effectiveLimit;
    _importedSalesRangeMonths = effectiveRangeMonths;
    final requestId = ++_importedSalesRequestId;
    // Only a global MANAGER may request a non-default scope. For everyone
    // else the backend ignores/validates the value against their own branch.
    final branchFilter = isGlobalManager ? _importedSalesBranchFilter : null;

    final localScope = _resolvedSalesScope();
    final cacheKey = _importedSalesCacheKey(
      targetMonth,
      localScope,
      effectiveLimit,
      effectiveRangeMonths,
      include,
    );
    final cached = _importedSalesCache[cacheKey];
    final contextChanged =
        previousMonth != targetMonth || previousScope != localScope;

    if (cached != null &&
        DateTime.now().difference(cached.fetchedAt) <
            CacheConfig.importedSales) {
      _importedSalesSummary = cached.data;
      _importedSalesVersion = cached.version;
      _importedSalesScope = cached.scope;
    }

    _importedSalesLoading = true;
    _importedSalesError = null;
    if (contextChanged) {
      _importedSalesComparison = null;
      _importedSalesComparisonDetail = null;
    }
    notifyListeners();

    try {
      final versionInfo = await _repo.getImportedSalesVersion(
        month: targetMonth,
        rangeMonths: effectiveRangeMonths,
        branch: branchFilter,
      );
      // A newer request (month/limit change) superseded this one.
      if (requestId != _importedSalesRequestId) return false;
      final serverScope = versionInfo['scope']?.toString() ?? localScope;
      final serverVersion = (versionInfo['version'] as num?)?.toInt() ?? 0;
      _importedSalesScope = serverScope;
      _importedSalesVersion = serverVersion;

      final serverKey = _importedSalesCacheKey(
        targetMonth,
        serverScope,
        effectiveLimit,
        effectiveRangeMonths,
        include,
      );
      final serverCached = _importedSalesCache[serverKey];
      final targetUpdatedAt = versionInfo['target_updated_at']?.toString();
      final cachedTargetUpdatedAt = serverCached?.data['target_updated_at']
          ?.toString();

      // Unchanged version -> cached payload is still exact; no summary GET.
      if (!forceRefresh &&
          serverCached != null &&
          serverCached.version == serverVersion &&
          cachedTargetUpdatedAt == targetUpdatedAt) {
        _importedSalesSummary = serverCached.data;
        // The summary cache and comparison/detail cache are independent.
        // Always restore the latter when the summary itself is still current.
        await fetchImportedSalesComparison();
        return true;
      }

      final data = await _repo.getImportedSalesSummary(
        month: targetMonth,
        rangeMonths: effectiveRangeMonths,
        limit: effectiveLimit,
        include: include,
        branch: branchFilter,
      );
      if (requestId != _importedSalesRequestId) return false;
      final dataVersion = (data['version'] as num?)?.toInt() ?? serverVersion;
      final dataScope = data['scope']?.toString() ?? serverScope;
      _importedSalesSummary = data;
      _importedSalesVersion = dataVersion;
      _importedSalesScope = dataScope;
      _importedSalesCache[_importedSalesCacheKey(
        targetMonth,
        dataScope,
        effectiveLimit,
        effectiveRangeMonths,
        include,
      )] = _ImportedSalesCacheEntry(
        data: data,
        version: dataVersion,
        scope: dataScope,
        fetchedAt: DateTime.now(),
      );
      // Fetch pembanding di latar belakang; tidak menunggu sebelum menampilkan
      // ringkasan bulan terpilih.
      fetchImportedSalesComparison();
      return true;
    } catch (e) {
      if (requestId != _importedSalesRequestId) return false;
      _importedSalesError = e is ApiException ? e.message : e.toString();
      if (cached != null) {
        // Fallback: keep the last good payload visible instead of blanking.
        _importedSalesSummary = cached.data;
        _importedSalesVersion = cached.version;
        _importedSalesScope = cached.scope;
      }
      return false;
    } finally {
      // Only the newest request owns the loading flag.
      if (requestId == _importedSalesRequestId) {
        _importedSalesLoading = false;
        notifyListeners();
      }
    }
  }

  void setImportedSalesRangeMonths(int rangeMonths) {
    if (![1, 3, 6, 12].contains(rangeMonths)) {
      throw ArgumentError.value(rangeMonths, 'rangeMonths');
    }
    if (_importedSalesRangeMonths == rangeMonths) return;
    _importedSalesRangeMonths = rangeMonths;
    _importedSalesRequestId++;
    _importedSalesSummary = null;
    _importedSalesError = null;
    notifyListeners();
  }

  /// Ganti jumlah bulan pembanding (1/3/6/12). Hanya fetch payload
  /// pembanding; ringkasan bulan terpilih tidak disentuh.
  Future<void> setImportedSalesComparisonMonths(int months) async {
    if (![1, 3, 6, 12].contains(months)) {
      throw ArgumentError.value(months, 'months');
    }
    if (_importedSalesComparisonMonths == months) return;
    _importedSalesComparisonMonths = months;
    _importedSalesComparison = null;
    notifyListeners();
    await fetchImportedSalesComparison();
  }

  /// Fetch payload pembanding untuk bulan/skope saat ini. Silence errors:
  /// pembanding adalah hiasan, tidak boleh memblokir tampilan utama.
  Future<void> fetchImportedSalesComparison() async {
    final month = _importedSalesMonth ?? _currentImportedSalesMonth();
    final branch = isGlobalManager ? _importedSalesBranchFilter : null;
    final cacheKey =
        '$month|${_importedSalesScope ?? ''}|$_importedSalesComparisonMonths';
    final cached = _importedSalesComparisonCache[cacheKey];
    if (cached != null) {
      _importedSalesComparison = cached;
      await fetchImportedSalesComparisonDetail();
      notifyListeners();
      return;
    }
    try {
      final data = await _repo.getImportedSalesComparison(
        month: month,
        months: _importedSalesComparisonMonths,
        branch: branch,
      );
      _importedSalesComparisonCache[cacheKey] = data;
      _importedSalesComparison = data;
      // Fetch detail dimensi (produk/pelanggan/divisi) untuk ranking
      // pembanding di latar belakang; error di-silent.
      await fetchImportedSalesComparisonDetail();
    } catch (_) {
      _importedSalesComparison = null;
    } finally {
      notifyListeners();
    }
  }

  /// Fetch detail dimensi pembanding (produk, pelanggan, divisi) sebagai
  /// daftar SalesRankItem dengan nilai rata-rata per bulan.
  Future<void> fetchImportedSalesComparisonDetail() async {
    final month = _importedSalesMonth ?? _currentImportedSalesMonth();
    final branch = isGlobalManager ? _importedSalesBranchFilter : null;
    final cacheKey =
        '$month|${_importedSalesScope ?? ''}|$_importedSalesComparisonMonths|detail';
    final cached = _importedSalesComparisonCache[cacheKey];
    if (cached != null) {
      _importedSalesComparisonDetail = _parseComparisonDetail(cached);
      return;
    }
    try {
      final data = await _repo.getImportedSalesComparison(
        month: month,
        months: _importedSalesComparisonMonths,
        include: 'product,customer,divisi',
        branch: branch,
      );
      _importedSalesComparisonCache[cacheKey] = data;
      _importedSalesComparisonDetail = _parseComparisonDetail(data);
    } catch (_) {
      _importedSalesComparisonDetail = null;
    }
  }

  Map<String, List<SalesRankItem>> _parseComparisonDetail(
    Map<String, dynamic> data,
  ) {
    int toInt(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    return {
      'product': (data['by_product'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .map(
            (e) => SalesRankItem(
              code: e['product_kode']?.toString().trim() ?? '',
              label: e['product_nama']?.toString().trim() ?? '',
              qty: toInt(e['qty']),
              revenue: toInt(e['average_revenue'] ?? e['revenue']),
              margin: toInt(e['average_margin'] ?? e['margin']),
              motherSku: e['mother_sku']?.toString(),
              productKode: e['product_kode']?.toString(),
            ),
          )
          .toList(growable: false),
      'customer': (data['by_customer'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .map(
            (e) => SalesRankItem(
              code: e['customer_kode']?.toString().trim() ?? '',
              label: e['customer_nama']?.toString().trim() ?? '',
              qty: toInt(e['qty']),
              revenue: toInt(e['average_revenue'] ?? e['revenue']),
              margin: toInt(e['average_margin'] ?? e['margin']),
            ),
          )
          .toList(growable: false),
      'divisi': (data['by_divisi'] as List? ?? const [])
          .whereType<Map<dynamic, dynamic>>()
          .map<Map<String, dynamic>>((e) => Map<String, dynamic>.from(e))
          .map(
            (e) => SalesRankItem(
              code: e['divisi']?.toString().trim() ?? '',
              label: e['divisi']?.toString().trim() ?? '',
              qty: toInt(e['qty']),
              revenue: toInt(e['average_revenue'] ?? e['revenue']),
              margin: toInt(e['average_margin'] ?? e['margin']),
            ),
          )
          .toList(growable: false),
    };
  }

  Future<Map<String, int>> getImportedSalesMonthTotals(String month) async {
    final summary = await _repo.getImportedSalesSummary(
      month: month,
      rangeMonths: 1,
      limit: 1,
      include: 'day',
      branch: isGlobalManager ? _importedSalesBranchFilter : null,
    );
    return {
      'rows': (summary['imported_rows'] as num?)?.toInt() ?? 0,
      'revenue': (summary['total_revenue'] as num?)?.toInt() ?? 0,
      'retur_rows': (summary['total_retur_rows'] as num?)?.toInt() ?? 0,
      'retur_revenue': (summary['total_retur_revenue'] as num?)?.toInt() ?? 0,
    };
  }

  Future<bool> deleteImportedSalesReturnsMonth({
    required String month,
    String? branch,
    bool allBranches = false,
  }) async {
    _setLoading(true, 'Menghapus data retur...');
    try {
      final result = await _repo.deleteImportedSalesReturnsMonth(
        month: month,
        branch: branch,
        allBranches: allBranches,
      );
      _salesReturnImportResult = result;
      _importedSalesCache.clear();
      _setLoading(false);
      await loadImportedSalesSummary(
        month: month,
        rangeMonths: _importedSalesRangeMonths,
        forceRefresh: true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteImportedSalesMonth({
    required String month,
    String? branch,
    bool allBranches = false,
  }) async {
    _setLoading(true, 'Menghapus data penjualan...');
    try {
      final result = await _repo.deleteImportedSalesMonth(
        month: month,
        branch: branch,
        allBranches: allBranches,
      );
      _salesImportResult = result;
      _importedSalesCache.clear();
      _setLoading(false);
      await loadImportedSalesSummary(
        month: month,
        rangeMonths: _importedSalesRangeMonths,
        forceRefresh: true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Hapus semua target import (sales/supplier/divisi) untuk satu periode.
  Future<bool> deleteImportedSalesTargets({required String period}) async {
    _setLoading(true, 'Menghapus target penjualan...');
    try {
      final branch = importedSalesBranchFilter;
      await _repo.deleteImportedSalesTargets(
        period: period,
        branch: branch,
        allBranches: branch == null,
      );
      _importedSalesCache.clear();
      _importedSalesComparisonCache.clear();
      _setLoading(false);
      await loadImportedSalesSummary(
        month: period,
        rangeMonths: _importedSalesRangeMonths,
        forceRefresh: true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Hapus SEMUA data penjualan & retur hasil import, semua cabang.
  Future<bool> deleteAllImportedSales() async {
    _setLoading(true, 'Menghapus semua data penjualan...');
    try {
      await _repo.deleteAllImportedSales();
      _importedSalesCache.clear();
      _importedSalesComparisonCache.clear();
      _setLoading(false);
      await loadImportedSalesSummary(
        month: _importedSalesMonth,
        rangeMonths: _importedSalesRangeMonths,
        forceRefresh: true,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> importSalesExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    _salesImportResult = null;
    _setLoading(true, 'Mengimport laporan penjualan...');
    try {
      final raw = await _repo.importSalesExcel(
        fileBytes,
        fileName,
        jobId: jobId,
        onSendProgress: onSendProgress,
      );
      final result = raw is Map
          ? Map<String, dynamic>.from(raw)
          : <String, dynamic>{};
      _salesImportResult = result;
      final success = result['success'] == true;
      _setLoading(false);

      if (!success) {
        String? reason;
        final errors = result['errors'];
        if (errors is List && errors.isNotEmpty && errors.first is Map) {
          reason = (errors.first as Map)['reason']?.toString();
        }
        _errorMessage =
            reason ?? 'Import laporan penjualan gagal. Periksa format file.';
        notifyListeners();
        return false;
      }

      // Only drop the cached summary when the import actually changed data.
      // A pure re-import (all rows matched unchanged) returns no versions and
      // leaves the existing snapshot valid, so the next probe can reuse it.
      final versions = result['versions'];
      final changed = versions is! List || versions.isNotEmpty;
      if (changed) {
        invalidateImportedSalesCache();
      }
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> importSalesReturnsExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    _salesReturnImportResult = null;
    _errorMessage = null;
    _setLoading(true, 'Mengimport laporan retur...');
    try {
      final result = await _repo.importSalesReturnsExcel(
        fileBytes,
        fileName,
        jobId: jobId,
        onSendProgress: onSendProgress,
      );
      _salesReturnImportResult = result;
      if (result['success'] != true) {
        final errors = result['errors'];
        final firstError = errors is List && errors.isNotEmpty
            ? errors.first
            : null;
        _errorMessage = firstError is Map
            ? firstError['reason']?.toString()
            : 'Import retur gagal. Periksa format file.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final versions = result['versions'];
      if (versions is! List || versions.isNotEmpty) {
        invalidateImportedSalesCache();
      }
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> importSalesTargetsExcel(
    List<int> fileBytes,
    String fileName, {
    String? jobId,
    void Function(int sent, int total)? onSendProgress,
  }) async {
    _salesTargetImportResult = null;
    _errorMessage = null;
    _setLoading(true, 'Mengimport target penjualan...');
    try {
      final result = await _repo.importSalesTargetsExcel(
        fileBytes,
        fileName,
        jobId: jobId,
        onSendProgress: onSendProgress,
      );
      _salesTargetImportResult = result;
      if (result['success'] != true) {
        final errors = result['errors'];
        final firstError = errors is List && errors.isNotEmpty
            ? errors.first
            : null;
        _errorMessage = firstError is Map
            ? firstError['reason']?.toString()
            : 'Import target penjualan gagal. Periksa format file.';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final changed =
          ((result['inserted'] as num?)?.toInt() ?? 0) +
              ((result['updated'] as num?)?.toInt() ?? 0) >
          0;
      if (changed) invalidateImportedSalesCache();
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<SyncError>> getSyncErrors() async {
    return await _repo.getSyncErrors();
  }

  Future<List<Map<String, dynamic>>> getImportLogs() async {
    return await _repo.getImportLogs();
  }

  Future<bool> clearImportErrors() async {
    try {
      await _repo.clearImportErrors();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  // ===== Product Sales Stats (Performa Sales — KPI per Produk) =====
  List<Map<String, dynamic>> _productSalesStats = [];
  bool _productSalesStatsLoading = false;
  String? _productSalesStatsYearMonth;

  List<Map<String, dynamic>> get productSalesStats => _productSalesStats;
  bool get productSalesStatsLoading => _productSalesStatsLoading;
  String? get productSalesStatsYearMonth => _productSalesStatsYearMonth;

  Future<void> loadProductSalesStats({String? yearMonth}) async {
    _productSalesStatsLoading = true;
    _productSalesStatsYearMonth = yearMonth;
    notifyListeners();
    try {
      _productSalesStats = await _repo.getProductSalesStats(
        yearMonth: yearMonth,
      );
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _productSalesStatsLoading = false;
      notifyListeners();
    }
  }

  // ===== Supplier Performance (Performa Sales — KPI per Supplier) =====
  List<SupplierPerformanceRow> _supplierPerformance = [];
  bool _supplierPerformanceLoading = false;
  String? _supplierPerformanceYearMonth;
  String? _supplierPerformanceBranch;
  String? _supplierPerformanceError;
  List<BranchOption> _branchOptions = [];
  bool _branchOptionsLoading = false;
  String? _branchOptionsError;

  List<SupplierPerformanceRow> get supplierPerformance => _supplierPerformance;
  bool get supplierPerformanceLoading => _supplierPerformanceLoading;
  String? get supplierPerformanceYearMonth => _supplierPerformanceYearMonth;
  String? get supplierPerformanceBranch => _supplierPerformanceBranch;

  /// Error khusus KPI supplier — supaya tabel KPI tidak menampilkan error
  /// dari request lain (leaderboard, target sales, dsb).
  String? get supplierPerformanceError => _supplierPerformanceError;
  List<BranchOption> get branchOptions => _branchOptions;
  bool get branchOptionsLoading => _branchOptionsLoading;
  String? get branchOptionsError => _branchOptionsError;

  /// Load the active branch list for the MANAGER branch picker (cached per
  /// session; call again only after branch master data changes).
  Future<void> loadBranchOptions() async {
    if (_branchOptionsLoading) return;
    _branchOptionsLoading = true;
    _branchOptionsError = null;
    try {
      _branchOptions = await _repo.getBranches();
    } catch (e) {
      _branchOptionsError = e is ApiException ? e.message : e.toString();
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _branchOptionsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSupplierPerformance({
    String? yearMonth,
    String? branch,
  }) async {
    _supplierPerformanceLoading = true;
    _supplierPerformanceYearMonth = yearMonth;
    _supplierPerformanceBranch = branch;
    _supplierPerformanceError = null;
    // Kosongkan list supaya error/refresh tidak menyisakan baris periode lama.
    _supplierPerformance = [];
    notifyListeners();
    try {
      _supplierPerformance = await _repo.getSupplierPerformance(
        yearMonth: yearMonth,
        branch: branch,
      );
      _errorMessage = null;
    } catch (e) {
      _supplierPerformanceError = e is ApiException ? e.message : e.toString();
    } finally {
      _supplierPerformanceLoading = false;
      notifyListeners();
    }
  }

  /// Upsert a supplier's monthly target. Backend: SUPERVISOR / MANAGER only.
  /// Throws on failure (caller shows SnackBar).
  Future<void> updateSupplierTarget({
    required String branch,
    required String supplierName,
    required String period,
    required int targetValue,
  }) async {
    try {
      await _repo.updateSupplierTarget(
        branch: branch,
        supplierName: supplierName,
        period: period,
        targetValue: targetValue,
      );
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // ===== Sales Performance (Manager only) =====

  Future<void> loadSalesPerformance({
    required DateTime from,
    required DateTime to,
  }) async {
    _performanceLoading = true;
    _performanceDateFrom = from;
    _performanceDateTo = to;
    notifyListeners();
    try {
      _performanceList = await _repo.getSalesPerformance(
        fromDate: from,
        toDate: to,
      );
      _salesPerformanceCacheTime = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _performanceLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadSalesPerformanceDashboard() async {
    _dashboardPerformanceLoading = true;
    notifyListeners();
    try {
      _dashboardPerformance = await _repo.getSalesPerformanceDashboard();
      _salesPerformanceCacheTime = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      if (e is! DioException || !CancelToken.isCancel(e)) {
        _errorMessage = e.toString();
      }
    } finally {
      _dashboardPerformanceLoading = false;
      notifyListeners();
    }
  }

  // ===== Popup detail order untuk dashboard sales =====
  List<Order> _salesDetailOrders = [];
  int _salesDetailTotalOrders = 0;
  int _salesDetailTotalRevenue = 0;
  int _salesDetailTotalDiscount = 0;
  int _salesDetailTotalUpPrice = 0;
  bool _salesDetailLoading = false;
  String? _salesDetailError;
  String? _salesDetailStatus;
  DateTime? _salesDetailDateFrom;
  DateTime? _salesDetailDateTo;

  List<Order> get salesDetailOrders => _salesDetailOrders;

  /// Total dari server untuk seluruh hasil filter.
  int get salesDetailTotalOrders => _salesDetailTotalOrders;
  int get salesDetailTotalRevenue => _salesDetailTotalRevenue;
  int get salesDetailTotalDiscount => _salesDetailTotalDiscount;
  int get salesDetailTotalUpPrice => _salesDetailTotalUpPrice;
  bool get salesDetailLoading => _salesDetailLoading;
  String? get salesDetailError => _salesDetailError;
  String? get salesDetailStatus => _salesDetailStatus;
  DateTime? get salesDetailDateFrom => _salesDetailDateFrom;
  DateTime? get salesDetailDateTo => _salesDetailDateTo;

  Future<void> loadSalesDetailOrders({
    String? salesId,
    String? branch,
    String? status,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    _salesDetailLoading = true;
    _salesDetailError = null;
    _salesDetailStatus = status;
    _salesDetailDateFrom = dateFrom;
    _salesDetailDateTo = dateTo;
    notifyListeners();
    try {
      final res = await _repo.getOrdersBySales(
        salesId: salesId,
        branch: branch,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      _salesDetailOrders = res.orders;
      _salesDetailTotalOrders = res.total;
      _salesDetailTotalRevenue = res.totalAmount;
      _salesDetailTotalDiscount = res.totalDiscount;
      _salesDetailTotalUpPrice = res.totalUpPrice;
    } catch (e) {
      _salesDetailError = e is ApiException ? e.message : e.toString();
    } finally {
      _salesDetailLoading = false;
      notifyListeners();
    }
  }

  void clearSalesDetailOrders() {
    _salesDetailOrders = [];
    _salesDetailTotalOrders = 0;
    _salesDetailTotalRevenue = 0;
    _salesDetailTotalDiscount = 0;
    _salesDetailTotalUpPrice = 0;
    _salesDetailError = null;
    _salesDetailStatus = null;
    _salesDetailDateFrom = null;
    _salesDetailDateTo = null;
    notifyListeners();
  }

  void setPerformanceSort(String sort) {
    _performanceSort = sort;
    notifyListeners();
  }

  Future<void> loadSalesTargets({String? period}) async {
    _targetsLoading = true;
    notifyListeners();
    try {
      _salesTargets = await _repo.getSalesTargets(period: period);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _targetsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateSalesTarget({
    required String userId,
    required String period,
    required String targetType,
    required int targetValue,
    required int incentiveAmount,
  }) async {
    try {
      final updated = await _repo.updateSalesTarget(
        userId: userId,
        period: period,
        targetType: targetType,
        targetValue: targetValue,
        incentiveAmount: incentiveAmount,
      );
      // Upsert: replace existing or add new
      final idx = _salesTargets.indexWhere(
        (t) => t.userId == userId && t.period == period,
      );
      if (idx >= 0) {
        _salesTargets[idx] = updated;
      } else {
        _salesTargets.add(updated);
      }
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Return target for a given userId + period, or null if not set.
  SalesTarget? getTargetFor(String userId, String period) {
    try {
      return _salesTargets.firstWhere(
        (t) => t.userId == userId && t.period == period,
      );
    } catch (_) {
      return null;
    }
  }

  // ===== Bulletins =====

  Future<void> loadBulletins({bool includeRead = false}) async {
    _bulletinsLoading = true;
    notifyListeners();
    try {
      _bulletins = await _repo.getBulletins(includeRead: includeRead);
      // Sort newest first
      _bulletins.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _bulletinsCacheTime = DateTime.now(); // Update cache timestamp
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _bulletinsLoading = false;
      notifyListeners();
    }
  }

  Future<bool> createBulletin({
    required String title,
    String? description,
    String? pdfUrl,
    DateTime? expireAt,
  }) async {
    _setLoading(true, 'Membuat bulletin...');
    try {
      final bulletin = await _repo.createBulletin(
        title: title,
        description: description,
        pdfUrl: pdfUrl,
        expireAt: expireAt,
      );
      _bulletins = [bulletin, ..._bulletins];
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateBulletin(
    String id, {
    String? title,
    String? description,
    String? pdfUrl,
    DateTime? expireAt,
  }) async {
    _setLoading(true, 'Menyimpan bulletin...');
    try {
      final updated = await _repo.updateBulletin(
        id,
        title: title,
        description: description,
        pdfUrl: pdfUrl,
        expireAt: expireAt,
      );
      _bulletins = [for (final b in _bulletins) b.id == id ? updated : b];
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteBulletin(String id) async {
    _setLoading(true, 'Menghapus bulletin...');
    try {
      await _repo.deleteBulletin(id);
      _bulletins = _bulletins.where((b) => b.id != id).toList();
      _setLoading(false);
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
