import 'package:flutter/foundation.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/api_exception.dart';
import 'draft_order_provider.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepo;
  static const int _pageSize = 20;
  // Cache order selama 2 menit untuk mencegah reload berulang.
  static const Duration _orderCacheDuration = Duration(minutes: 2);

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _activeStatusFilter;
  DateTime? _lastLoadTime;

  // Dipakai khusus untuk section "Orderan Terbaru" di Beranda.
  // Dipisah dari `_orders` supaya filter yang dipasang di halaman Pesanan
  // tidak mengotori tampilan Orderan Terbaru.
  List<Order> _recentOrders = [];
  bool _isLoadingRecent = false;

  OrderProvider(this._orderRepo);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get activeStatusFilter => _activeStatusFilter;

  List<Order> get recentOrders => _recentOrders;
  bool get isLoadingRecent => _isLoadingRecent;

  int countByStatus(String status) {
    return _orders.where((o) => o.status == status).length;
  }

  /// Cek apakah cache order masih valid (belum lewat durasi cache).
  bool get _isOrderCacheValid {
    if (_lastLoadTime == null || _orders.isEmpty) return false;
    return DateTime.now().difference(_lastLoadTime!) < _orderCacheDuration;
  }

  Future<void> loadOrders({String? status, bool reset = true}) async {
    // Jika cache masih valid dan tidak ada filter baru, skip reload.
    if (reset && _isOrderCacheValid && status == _activeStatusFilter) {
      return;
    }

    if (reset) {
      _isLoading = true;
      _hasMore = true;
    }
    _errorMessage = null;
    _activeStatusFilter = status;
    notifyListeners();

    try {
      final newOrders = await _orderRepo.getMyOrders(
        skip: reset ? 0 : _orders.length,
        limit: _pageSize,
        status: status,
      );
      if (reset) {
        _orders = newOrders;
      } else {
        _orders.addAll(newOrders);
      }
      _hasMore = newOrders.length >= _pageSize;
      _lastLoadTime = DateTime.now();
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e, st) {
      debugPrint('loadOrders failed: $e\n$st');
      _errorMessage = 'Gagal memuat daftar pesanan (${e.runtimeType})';
    }

    _isLoading = false;
    _isLoadingMore = false;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    notifyListeners();
    await loadOrders(status: _activeStatusFilter, reset: false);
  }

  /// Re-fetch dengan filter aktif saat ini — dipakai setelah mutasi (delete/submit)
  /// supaya list otomatis update tanpa harus trigger refresh manual.
  Future<void> refreshOrders() async {
    await loadOrders(status: _activeStatusFilter, reset: true);
  }

  /// Ambil 5 order terbaru (semua status) khusus untuk section "Orderan Terbaru"
  /// di Beranda. Tidak pernah append — selalu replace list supaya tampilan
  /// Orderan Terbaru konsisten dengan backend dan tidak terkontaminasi filter
  /// yang dipasang di halaman Pesanan.
  Future<void> loadRecentOrders() async {
    _isLoadingRecent = true;
    notifyListeners();

    try {
      _recentOrders = await _orderRepo.getMyOrders(
        skip: 0,
        limit: 5,
        status: null,
      );
    } catch (e) {
      // Diam saja — fallback ke list sebelumnya supaya UI tidak blank.
    }

    _isLoadingRecent = false;
    notifyListeners();
  }

  Future<Order?> getOrderDetail(String orderId) async {
    try {
      return await _orderRepo.getOrderDetail(orderId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Order?> createOrder({
    required String customerId,
    required List<Map<String, dynamic>> items,
    Map<String, ItemDiscount>? discounts,
    String? notes,
    String orderType = 'REGULER',
    String? clientRequestId,
    String orderDiscountType = 'PERCENT',
    int orderDiscountNominal = 0,
    String orderUpPriceType = 'NOMINAL',
    int orderUpPriceNominal = 0,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _orderRepo.createOrder(
        customerId: customerId,
        items: items,
        notes: notes,
        orderType: orderType,
        clientRequestId: clientRequestId,
        orderDiscountType: orderDiscountType,
        orderDiscountNominal: orderDiscountNominal,
        orderUpPriceType: orderUpPriceType,
        orderUpPriceNominal: orderUpPriceNominal,
      );
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e, st) {
      debugPrint('createOrder failed: $e\n$st');
      _errorMessage = 'Gagal membuat order (${e.runtimeType})';
      notifyListeners();
      return null;
    }
  }

  Future<Order?> updateDraftOrder({
    required String orderId,
    required String customerId,
    required List<Map<String, dynamic>> items,
    Map<String, ItemDiscount>? discounts,
    String? notes,
    String orderType = 'REGULER',
    String orderDiscountType = 'PERCENT',
    int orderDiscountNominal = 0,
    String orderUpPriceType = 'NOMINAL',
    int orderUpPriceNominal = 0,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final order = await _orderRepo.updateOrder(
        orderId: orderId,
        customerId: customerId,
        items: items,
        notes: notes,
        orderType: orderType,
        orderDiscountType: orderDiscountType,
        orderDiscountNominal: orderDiscountNominal,
        orderUpPriceType: orderUpPriceType,
        orderUpPriceNominal: orderUpPriceNominal,
      );
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e, st) {
      // Generic fallback fires for non-API exceptions (e.g. Order.fromJson
      // TypeError when backend response shape is unexpected). Surface the
      // exception class in the message so the user/developer can tell at
      // a glance whether it's a TypeError / FormatException / etc., and
      // dump the full trace to debugPrint for the next investigation.
      debugPrint('updateDraftOrder failed: $e\n$st');
      _errorMessage = 'Gagal menyimpan draft (${e.runtimeType})';
      notifyListeners();
      return null;
    }
  }

  Future<bool> submitOrder(String orderId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepo.submitOrder(orderId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('submitOrder failed: $e\n$st');
      _errorMessage = 'Gagal mengirim order (${e.runtimeType})';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteOrder(String orderId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepo.deleteOrder(orderId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    } catch (e, st) {
      debugPrint('deleteOrder failed: $e\n$st');
      _errorMessage = 'Gagal menghapus draft (${e.runtimeType})';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepo.cancelOrder(orderId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    notifyListeners();
  }
}
