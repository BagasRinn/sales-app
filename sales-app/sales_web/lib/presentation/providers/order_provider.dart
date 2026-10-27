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

  Future<Order?> createOrder({
    required String customerId,
    required List<OrderItem> items,
    required String orderType,
    String? notes,
    String? clientRequestId,
  }) async {
    try {
      final order = await _orderRepo.createOrder(
        customerId: customerId,
        items: _itemsToMaps(items),
        orderType: orderType,
        notes: notes,
        clientRequestId: clientRequestId,
      );
      await loadOrders(status: _currentStatus);
      return order;
    } catch (e) {
      return null;
    }
  }

  Future<Order?> saveDraft({
    required String customerId,
    required List<OrderItem> items,
    required String orderType,
    String? notes,
    String? clientRequestId,
  }) async {
    try {
      final order = await _orderRepo.saveDraft(
        customerId: customerId,
        items: _itemsToMaps(items),
        orderType: orderType,
        notes: notes,
        clientRequestId: clientRequestId,
      );
      return order;
    } catch (e) {
      return null;
    }
  }

  List<Map<String, dynamic>> _itemsToMaps(List<OrderItem> items) {
    return items.map((item) {
      final d = item.discount;
      final l1 = d.layer1;
      final l2 = d.layer2;
      final l3 = d.layer3;
      return {
        'product_id': item.productId,
        'qty': item.qty,
        'discount_type': (l1?.type.name.toUpperCase() ?? 'PERCENT'),
        'discount_percent': l1?.type == DiscountType.percent ? (l1?.value ?? 0) : 0,
        'discount_nominal': l1?.type == DiscountType.nominal ? (l1?.value ?? 0) : 0,
        'discount2_type': (l2?.type.name.toUpperCase() ?? 'PERCENT'),
        'discount2_percent': l2?.type == DiscountType.percent ? (l2?.value ?? 0) : 0,
        'discount2_nominal': l2?.type == DiscountType.nominal ? (l2?.value ?? 0) : 0,
        'discount3_type': (l3?.type.name.toUpperCase() ?? 'PERCENT'),
        'discount3_percent': l3?.type == DiscountType.percent ? (l3?.value ?? 0) : 0,
        'discount3_nominal': l3?.type == DiscountType.nominal ? (l3?.value ?? 0) : 0,
        'up_price_type': item.upPriceType,
        'up_price_percent': item.upPricePercent,
        'up_price_nominal': item.upPriceNominal,
      };
    }).toList();
  }
}
