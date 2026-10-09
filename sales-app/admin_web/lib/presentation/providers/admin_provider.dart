import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import '../../core/api_exception.dart';

enum AdminState { initial, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  final AdminRepository _repo;

  AdminRepository get repository => _repo;

  AdminState _state = AdminState.initial;
  String? _errorMessage;

  List<Order> _pendingOrders = [];
  List<Order> _allOrders = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
  List<CustomerSubmission> _customerSubmissions = [];
  String? _customerSubmissionsStatus; // filter aktif: null = semua
  SyncResult? _lastSyncResult;
  Map<String, int> _stats = {};
  String? _loadingMessage;
  Timer? _autoRefreshTimer;
  bool _hasNewPending = false;

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

  // Filters
  String? _selectedSupplier;
  String? _selectedStatus;
  String? _orderFilter; // persists filter across approve/reject actions
  DateTime? _orderDateFrom;
  DateTime? _orderDateTo;
  String? _orderSearch; // search by store name or sales name
  int _orderSkip = 0; // pagination offset
  int _orderLimit = 20; // pagination page size
  int _orderTotal = 0; // total pesanan yang match filter (untuk pagination)

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

  AdminProvider(this._repo);

  /// Expose repo untuk widget yang butuh akses langsung (mis. download file).
  AdminRepository get adminRepository => _repo;

  AdminState get state => _state;
  String? get errorMessage => _errorMessage;
  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get allOrders => _allOrders;
  List<Product> get products => _products;
  List<Customer> get customers => _customers;
  List<CustomerSubmission> get customerSubmissions => _customerSubmissions;
  String? get customerSubmissionsStatus => _customerSubmissionsStatus;
  int get customerSubmissionsPendingCount =>
      _customerSubmissions.where((s) => s.status == 'PENDING').length;
  SyncResult? get lastSyncResult => _lastSyncResult;
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
  List<SalesPerformanceDashboardItem> get dashboardPerformance => _dashboardPerformance;
  bool get dashboardPerformanceLoading => _dashboardPerformanceLoading;

  // ===== Bulletins =====
  List<Bulletin> get bulletins => _bulletins;
  bool get bulletinsLoading => _bulletinsLoading;

  String _userRole = 'ADMIN';
  String get userRole => _userRole;
  bool get isAdmin => _userRole == 'ADMIN';
  bool get isManager => _userRole == 'MANAGER';

  void setUserRole(String role) {
    // Tidak notifyListeners: _userRole cuma dipakai loadAll() untuk skip endpoint
    // admin-only. UI pakai widget.role langsung dari DashboardScreen.
    _userRole = role;
  }

  /// Start auto-refresh. Call from dashboard initState.
  void startAutoRefresh({Duration interval = const Duration(seconds: 30)}) {
    stopAutoRefresh();
    _autoRefreshTimer = Timer.periodic(interval, (_) => _autoRefresh());
  }

  /// Stop auto-refresh. Call from dashboard dispose.
  void stopAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = null;
  }

  /// Clear the "new pending" badge after user sees it.
  void clearNewPendingBadge() {
    _hasNewPending = false;
    notifyListeners();
  }

  Future<void> _autoRefresh() async {
    if (_state == AdminState.loading) return; // skip if user-initiated load is active
    try {
      final prevLength = _pendingOrders.length;
      final prevStats = Map<String, int>.from(_stats);
      final prevSubmissionsLen = _customerSubmissions.length;
      final prevSubmissionsPending =
          _customerSubmissions.where((s) => s.status == 'PENDING').length;
      final tasks = <Future<void>>[
        _loadPendingOrders(),
        if (isAdmin || isManager) _loadStats(),
        // Refresh customer submissions only kalau sudah pernah di-load (avoid
        // hitting endpoint saat tab belum pernah dibuka).
        if (_customerSubmissions.isNotEmpty || _customerSubmissionsStatus != null)
          _loadCustomerSubmissionsSilent(),
      ];
      await Future.wait(tasks);
      // Only rebuild UI if data actually changed
      final pendingChanged = _pendingOrders.length != prevLength;
      final statsChanged = (isAdmin || isManager) && !_mapEquals(_stats, prevStats);
      final submissionsChanged = _customerSubmissions.length != prevSubmissionsLen ||
          _customerSubmissions.where((s) => s.status == 'PENDING').length !=
              prevSubmissionsPending;
      if (pendingChanged) {
        _hasNewPending = _pendingOrders.length > prevLength;
      }
      if (pendingChanged || statsChanged || submissionsChanged) {
        notifyListeners();
      }
    } catch (_) {
      // silent fail on auto-refresh — don't interrupt user, no rebuild on error
    }
  }

  bool _mapEquals(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  void _setLoading(bool loading, [String? msg]) {
    _state = loading ? AdminState.loading : AdminState.loaded;
    _loadingMessage = msg;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> loadPendingOrders({String? search}) async {
    try {
      _pendingOrders = await _repo.getPendingOrders(search: search);
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
      notifyListeners();
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
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
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
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

  Future<void> clearAllFilters() async {
    _selectedSupplier = null;
    _selectedStatus = null;
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
      _errorMessage = null;
    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) _errorMessage = e.toString();
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
    } catch (_) {
      // silent
    }
  }

  Future<void> searchCustomers(String query) async {
    _customerSearch = query;
    _customerPage = 0;
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounceDuration, () => loadCustomers());
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
  Future<List<SalesAssignment>> getCustomerAssignments(String customerId) async {
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

  Future<bool> updateCustomer(String customerId, Map<String, dynamic> body) async {
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
  }) async {
    _setLoading(true, 'Membuat user...');
    try {
      final newUser = await _repo.createUser(
        username: username,
        password: password,
        role: role,
        nama: nama,
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
      // Default: hitung per hari ini (WIT) supaya cards dashboard = aktivitas hari ini,
      // bukan total sepanjang masa di database.
      final effectiveDate = date ?? _todayWita();
      _stats = await _repo.getDashboardStats(date: effectiveDate, cancelToken: cancelToken);
      _errorMessage = null;
    } catch (e) {
      // Tangkap SEMUA error — Dio network errors throw di luar ApiException.
      // _stats = {} default, dashboard tampil 0 bukan blank/crash.
      if (!CancelToken.isCancel(e as DioException)) _errorMessage = e.toString();
    }
  }

  DateTime _todayWita() {
    // WITA = UTC+8. Dashboard "hari ini" mengikuti jam WITA biar konsisten
    // dengan sales app mobile (sudah pakai WITA di semua laporan).
    final now = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime(now.year, now.month, now.day);
  }

  Future<void> loadAll({DateTime? date}) async {
    _setLoading(true, 'Memuat data...');
    // Cancel any in-flight loadAll requests supaya server tidak kirim response
    // yang bakal diabaikan. Kalau user navigasi tab cepat, ini menghemat resource.
    final cancelToken = _newLoadToken();
    try {
      // Batch 1: orders + stats (dipakai Dashboard & Pesanan)
      await Future.wait([
        _loadPendingOrders(cancelToken),
        _loadAllOrders(cancelToken),
        if (isAdmin || isManager) _loadStats(date: date, cancelToken: cancelToken),
      ]);
      // Batch 2: customers + products (dipakai Toko + Produk). Dijalankan
      // setelah batch 1 supaya kalau tab Pesanan di-lewat cepat, batch 2
      // tidak jadi beban pada user concurrency.
      await Future.wait([
        _loadCustomers(cancelToken),
        _loadProducts(cancelToken),
      ]);
      _state = AdminState.loaded;
    } catch (e) {
      if (e is DioException && CancelToken.isCancel(e)) {
        // Cancelled — tidak perlu notify (request di-batalkan oleh user).
        return;
      }
      _state = AdminState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _loadPendingOrders([CancelToken? cancelToken]) async {
    try {
      _pendingOrders = await _repo.getPendingOrders(
        search: _orderSearch,
        cancelToken: cancelToken,
      );
      _errorMessage = null;
    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) _errorMessage = e.toString();
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
      _errorMessage = null;
    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) _errorMessage = e.toString();
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
          cancelToken: cancelToken,
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
          supplier: _selectedSupplier,
          status: _selectedStatus,
          cancelToken: cancelToken,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
      _errorMessage = null;
    } catch (e) {
      if (!CancelToken.isCancel(e as DioException)) _errorMessage = e.toString();
    }
  }

  Future<bool> approveOrder(String orderId) async {
    _setLoading(true, 'Menyetujui pesanan...');
    try {
      await _repo.approveOrder(orderId);
      await loadAll();
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
      await loadAll();
      return true;
    } catch (e) {
      _setLoading(false);
      _errorMessage = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrderItem(String orderId, int qty, String reason, String itemId) async {
    _setLoading(true, 'Membatalkan item...');
    try {
      await _repo.cancelOrderItems(orderId, items: [
        {'item_id': itemId, 'qty': qty, 'reason': reason},
      ]);
      await loadAll();
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

  Future<bool> importExcel(List<int> fileBytes, String fileName) async {
    _setLoading(true, 'Mengimport file Excel...');
    try {
      _lastSyncResult = await _repo.importExcel(fileBytes, fileName);
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

  Future<bool> importCustomersExcel(List<int> fileBytes, String fileName) async {
    _setLoading(true, 'Mengimport data toko...');
    try {
      _lastSyncResult = await _repo.importCustomersExcel(fileBytes, fileName);
      _setLoading(false);
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
      _performanceList = await _repo.getSalesPerformance(fromDate: from, toDate: to);
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
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e is ApiException ? e.message : e.toString();
    } finally {
      _dashboardPerformanceLoading = false;
      notifyListeners();
    }
  }

  // ===== Popup detail order untuk dashboard sales =====
  List<Order> _salesDetailOrders = [];
  bool _salesDetailLoading = false;
  String? _salesDetailError;
  String? _salesDetailStatus;
  DateTime? _salesDetailDateFrom;
  DateTime? _salesDetailDateTo;

  List<Order> get salesDetailOrders => _salesDetailOrders;
  bool get salesDetailLoading => _salesDetailLoading;
  String? get salesDetailError => _salesDetailError;
  String? get salesDetailStatus => _salesDetailStatus;
  DateTime? get salesDetailDateFrom => _salesDetailDateFrom;
  DateTime? get salesDetailDateTo => _salesDetailDateTo;

  Future<void> loadSalesDetailOrders({
    required String salesId,
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
      _salesDetailOrders = await _repo.getOrdersBySales(
        salesId: salesId,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    } catch (e) {
      _salesDetailError = e is ApiException ? e.message : e.toString();
    } finally {
      _salesDetailLoading = false;
      notifyListeners();
    }
  }

  void clearSalesDetailOrders() {
    _salesDetailOrders = [];
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
      _bulletins = [
        for (final b in _bulletins) b.id == id ? updated : b,
      ];
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
