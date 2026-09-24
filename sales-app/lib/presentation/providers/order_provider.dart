import 'package:flutter/foundation.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/api_exception.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepo;
  static const int _pageSize = 20;

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String? _activeStatusFilter;

  OrderProvider(this._orderRepo);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String? get activeStatusFilter => _activeStatusFilter;

  int countByStatus(String status) {
    return _orders.where((o) => o.status == status).length;
  }

  Future<void> loadOrders({String? status, bool reset = true}) async {
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
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Gagal memuat daftar pesanan';
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
    required Map<String, int> items,
    required Map<String, int> discounts,
    String? notes,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final itemsList = items.entries
          .map((e) => {
                'product_id': e.key,
                'qty': e.value,
                'discount_percent': discounts[e.key] ?? 0,
              })
          .toList();
      final order = await _orderRepo.createOrder(
        customerId: customerId,
        items: itemsList,
        notes: notes,
      );
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Gagal membuat order';
      notifyListeners();
      return null;
    }
  }

  Future<Order?> updateDraftOrder({
    required String orderId,
    required String customerId,
    required Map<String, int> items,
    required Map<String, int> discounts,
    String? notes,
  }) async {
    _errorMessage = null;
    notifyListeners();

    try {
      final itemsList = items.entries
          .map((e) => {
                'product_id': e.key,
                'qty': e.value,
                'discount_percent': discounts[e.key] ?? 0,
              })
          .toList();
      final order = await _orderRepo.updateOrder(
        orderId: orderId,
        customerId: customerId,
        items: itemsList,
        notes: notes,
      );
      notifyListeners();
      return order;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _errorMessage = 'Gagal menyimpan draft';
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
    } catch (e) {
      _errorMessage = 'Gagal mengirim order';
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
    } catch (e) {
      _errorMessage = 'Gagal menghapus draft';
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
