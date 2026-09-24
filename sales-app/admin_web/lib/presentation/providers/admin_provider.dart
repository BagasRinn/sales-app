import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/models/sync_result.dart';
import '../../data/models/customer.dart';
import '../../data/models/sales_user.dart';
import '../../data/models/sales_assignment.dart';
import '../../data/models/user_item.dart';
import '../../core/api_exception.dart';

enum AdminState { initial, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  final AdminRepository _repo;

  AdminState _state = AdminState.initial;
  String? _errorMessage;

  List<Order> _pendingOrders = [];
  List<Order> _allOrders = [];
  List<Product> _products = [];
  List<Customer> _customers = [];
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
  String? _selectedKategori;
  String? _selectedStatus;
  String? _orderFilter; // persists filter across approve/reject actions

  // Debounce timer for search
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  AdminProvider(this._repo);

  AdminState get state => _state;
  String? get errorMessage => _errorMessage;
  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get allOrders => _allOrders;
  List<Product> get products => _products;
  List<Customer> get customers => _customers;
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
  String? get selectedKategori => _selectedKategori;
  String? get selectedStatus => _selectedStatus;
  String? get orderFilter => _orderFilter;

  int get customerPage => _customerPage;
  int get customerLimit => _customerLimit;
  int get customerTotal => _customerTotal;
  int get customerTotalPages => (_customerTotal / _customerLimit).ceil();
  bool get hasPrevCustomerPage => _customerPage > 0;
  bool get hasNextCustomerPage => _customerPage < customerTotalPages - 1;
  String get customerSearch => _customerSearch;

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
      final tasks = <Future<void>>[
        _loadPendingOrders(),
        if (isAdmin) _loadStats(),
      ];
      await Future.wait(tasks);
      // Only rebuild UI if data actually changed
      final pendingChanged = _pendingOrders.length != prevLength;
      final statsChanged = isAdmin && !_mapEquals(_stats, prevStats);
      if (pendingChanged) {
        _hasNewPending = _pendingOrders.length > prevLength;
      }
      if (pendingChanged || statsChanged) {
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

  Future<void> loadPendingOrders() async {
    try {
      _pendingOrders = await _repo.getPendingOrders();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<void> loadAllOrders({String? status}) async {
    _orderFilter = status;
    try {
      _allOrders = await _repo.getAllOrders(status: status);
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
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
          kategori: _selectedKategori,
          status: _selectedStatus,
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
          kategori: _selectedKategori,
          status: _selectedStatus,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
  }

  Future<void> setKategoriFilter(String? kategori) async {
    _selectedKategori = kategori;
    _productPage = 0;
    await loadProducts();
  }

  Future<void> setStatusFilter(String? status) async {
    _selectedStatus = status;
    _productPage = 0;
    await loadProducts();
  }

  Future<void> clearAllFilters() async {
    _selectedKategori = null;
    _selectedStatus = null;
    _productSearch = '';
    _productPage = 0;
    _searchDebounceTimer?.cancel();
    await loadProducts();
  }

  Future<List<String>> getKategoriList() async {
    return await _repo.getKategoriList();
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

  Future<void> _loadCustomers() async {
    final results = await Future.wait([
      _repo.getCustomers(
        page: _customerPage,
        limit: _customerLimit,
        search: _customerSearch.isEmpty ? null : _customerSearch,
      ),
      _repo.getCustomerCount(
        search: _customerSearch.isEmpty ? null : _customerSearch,
      ),
    ]);
    _customers = results[0] as List<Customer>;
    _customerTotal = results[1] as int;
  }

  Future<void> loadCustomers() async {
    try {
      await _loadCustomers();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
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

  Future<List<SalesAssignment>> getCustomerAssignments(String customerId) async {
    return await _repo.getCustomerAssignments(customerId);
  }

  Future<List<SalesUser>> listSalesUsers() async {
    return await _repo.listSalesUsers();
  }

  Future<bool> updateCustomer(String customerId, Map<String, dynamic> body) async {
    _setLoading(true, 'Menyimpan perubahan...');
    try {
      await _repo.updateCustomer(customerId, body);
      await _loadCustomers();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> assignCustomerSales(String customerId, List<String> salesIds) async {
    _setLoading(true, 'Menyimpan assignment sales...');
    try {
      await _repo.assignCustomerSales(customerId, salesIds);
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  // ====== User management (manager only) ======
  List<UserItem> _users = [];
  String _userRoleFilter = '';
  String _userSearch = '';

  List<UserItem> get users => _users;
  String get userRoleFilter => _userRoleFilter;
  String get userSearch => _userSearch;

  Future<void> loadUsers({String? role, String? search}) async {
    if (role != null) _userRoleFilter = role;
    if (search != null) _userSearch = search;
    try {
      _users = await _repo.getUsers(
        role: _userRoleFilter.isEmpty ? null : _userRoleFilter,
        search: _userSearch.isEmpty ? null : _userSearch,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
  }

  Future<bool> createUser({
    required String username,
    required String password,
    required String role,
    String? nama,
  }) async {
    _setLoading(true, 'Membuat user...');
    try {
      await _repo.createUser(
        username: username,
        password: password,
        role: role,
        nama: nama,
      );
      await loadUsers();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateUser(String userId, Map<String, dynamic> body) async {
    _setLoading(true, 'Menyimpan perubahan...');
    try {
      await _repo.updateUser(userId, body);
      await loadUsers();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteUser(String userId) async {
    _setLoading(true, 'Menghapus user...');
    try {
      await _repo.deleteUser(userId);
      await loadUsers();
      _setLoading(false);
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> _loadStats() async {
    try {
      _stats = await _repo.getDashboardStats();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
  }

  Future<void> loadAll() async {
    _setLoading(true, 'Memuat data...');
    try {
      // MANAGER butuh stats untuk Dashboard (read-only).
      // MANAGER tidak butuh produk (tab Produk & Stok tidak ada untuk mereka).
      final tasks = <Future<void>>[
        _loadPendingOrders(),
        _loadAllOrders(),
        _loadCustomers(),
        _loadStats(),
      ];
      if (isAdmin) {
        tasks.add(_loadProducts());
      }
      await Future.wait(tasks);
      _state = AdminState.loaded;
    } catch (e) {
      _state = AdminState.error;
      _errorMessage = e.toString();
    }
    notifyListeners();
  }

  Future<void> _loadPendingOrders() async {
    try {
      _pendingOrders = await _repo.getPendingOrders();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
  }

  Future<void> _loadAllOrders() async {
    try {
      _allOrders = await _repo.getAllOrders(status: _orderFilter);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
  }

  Future<void> _loadProducts() async {
    final results = await Future.wait([
      _repo.getProducts(
        page: _productPage,
        limit: _productLimit,
        search: _productSearch.isEmpty ? null : _productSearch,
        kategori: _selectedKategori,
        status: _selectedStatus,
      ),
      _repo.getProductCount(
        search: _productSearch.isEmpty ? null : _productSearch,
        kategori: _selectedKategori,
        status: _selectedStatus,
      ),
    ]);
    _products = results[0] as List<Product>;
    _productTotal = results[1] as int;
  }

  Future<bool> approveOrder(String orderId) async {
    _setLoading(true, 'Menyetujui pesanan...');
    try {
      await _repo.approveOrder(orderId);
      await loadAll();
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectOrder(String orderId) async {
    _setLoading(true, 'Menolak pesanan...');
    try {
      await _repo.rejectOrder(orderId);
      await loadAll();
      return true;
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _setLoading(false);
      _errorMessage = e.message;
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
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
