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
  int _lastPendingCount = 0;
  bool _hasNewPending = false;

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
      final prev = _pendingOrders;
      await _loadPendingOrders();
      await _loadStats();
      // Detect new pending orders
      if (_pendingOrders.length > prev.length) {
        _hasNewPending = true;
      }
      if (_pendingOrders.length != _lastPendingCount) {
        _lastPendingCount = _pendingOrders.length;
      }
    } catch (_) {
      // silent fail on auto-refresh — don't interrupt user
    }
    notifyListeners();
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
      _products = await _repo.getProducts();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<void> loadStats() async {
    try {
      _stats = await _repo.getDashboardStats();
      notifyListeners();
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
    }
  }

  Future<void> loadAll() async {
    _setLoading(true, 'Memuat data...');
    try {
      await _loadPendingOrders();
      await _loadAllOrders();
      await _loadProducts();
      await _loadStats();
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
    try {
      _products = await _repo.getProducts();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
  }

  Future<void> _loadStats() async {
    try {
      _stats = await _repo.getDashboardStats();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    }
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
      await loadProducts();
      await loadStats();
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
      await loadProducts();
      await loadStats();
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

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
