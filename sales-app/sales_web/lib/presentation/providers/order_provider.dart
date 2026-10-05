import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';

class OrderProvider with ChangeNotifier {
  final OrderRepository _orderRepo;

  List<Order> _orders = [];
  List<Order> _recentOrders = [];
  bool _isLoading = false;
  String? _error;
  int _skip = 0;
  bool _hasMore = true;
  String? _currentStatus;
  String? _currentSearch;
  final int _limit = 20;

  OrderProvider(this._orderRepo);

  List<Order> get orders => _orders;
  List<Order> get recentOrders => _recentOrders;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadOrders({String? status, bool reset = true, String? search}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    if (reset) {
      _skip = 0;
      _hasMore = true;
    }
    _currentStatus = status;
    _currentSearch = search;
    notifyListeners();

    try {
      final result = await _orderRepo.getMyOrders(
        skip: _skip,
        limit: _limit,
        status: status,
        search: search,
      );
      if (reset) {
        _orders = result;
      } else {
        _orders.addAll(result);
      }
      _hasMore = result.length >= _limit;
      _skip += result.length;
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat pesanan.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreOrders() async {
    if (!_hasMore || _isLoading) return;
    await loadOrders(status: _currentStatus, reset: false, search: _currentSearch);
  }

  Future<void> loadRecentOrders() async {
    try {
      final result = await _orderRepo.getMyOrders(skip: 0, limit: 5);
      _recentOrders = result;
      notifyListeners();
    } catch (_) {}
  }

  int countByStatus(String status) {
    return _orders.where((o) => o.status == status).length;
  }

  Future<Order?> getOrderDetail(String orderId) async {
    try {
      return await _orderRepo.getOrderDetail(orderId);
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteOrder(String orderId) async {
    try {
      await _orderRepo.deleteOrder(orderId);
      _orders.removeWhere((o) => o.id == orderId);
      _recentOrders.removeWhere((o) => o.id == orderId);
      notifyListeners();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    try {
      await _orderRepo.cancelOrder(orderId);
      await loadOrders(status: _currentStatus);
      return true;
    } catch (e) {
      return false;
    }
  }
}
