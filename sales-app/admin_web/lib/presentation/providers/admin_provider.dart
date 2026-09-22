import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/models/order.dart';
import '../../data/models/product.dart';
import '../../data/models/sync_result.dart';
import '../../core/api_exception.dart';

enum AdminState { initial, loading, loaded, error }

class AdminProvider extends ChangeNotifier {
  final AdminRepository _repo;

  AdminState _state = AdminState.initial;
  String? _errorMessage;

  List<Order> _pendingOrders = [];
  List<Order> _allOrders = [];
  List<Product> _products = [];
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

  // Debounce timer for search
  Timer? _searchDebounceTimer;
  static const _searchDebounceDuration = Duration(milliseconds: 400);

  AdminProvider(this._repo);

  AdminState get state => _state;
  String? get errorMessage => _errorMessage;
  List<Order> get pendingOrders => _pendingOrders;
  List<Order> get allOrders => _allOrders;
  List<Product> get products => _products;
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
      await Future.wait([
        _loadPendingOrders(),
        _loadStats(),
      ]);
      // Only rebuild UI if data actually changed
      final pendingChanged = _pendingOrders.length != prevLength;
      final statsChanged = !_mapEquals(_stats, prevStats);
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
        ),
        _repo.getProductCount(
          search: _productSearch.isEmpty ? null : _productSearch,
        ),
      ]);
      _products = results[0] as List<Product>;
      _productTotal = results[1] as int;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
    notifyListeners();
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
      await Future.wait([
        _loadPendingOrders(),
        _loadAllOrders(),
        _loadProducts(),
        _loadStats(),
      ]);
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
      _allOrders = await _repo.getAllOrders();
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
      ),
      _repo.getProductCount(
        search: _productSearch.isEmpty ? null : _productSearch,
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
    _setLoading(true, 'Menyinkronkan data dari Google Sheets...');
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
