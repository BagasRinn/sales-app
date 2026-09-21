import 'package:flutter/foundation.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';
import '../../core/api_exception.dart';

class OrderProvider extends ChangeNotifier {
  final OrderRepository _orderRepo;

  List<Order> _orders = [];
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  OrderProvider(this._orderRepo);

  List<Order> get orders => _orders;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  String? get successMessage => _successMessage;

  Future<void> loadMyOrders({String? status}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _orders = await _orderRepo.getMyOrders(status: status);
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Gagal memuat riwayat pesanan';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> checkout(
    List<Map<String, dynamic>> items, {
    String? storeName,
    String? storeContact,
    String? storeAddress,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();

    try {
      await _orderRepo.checkout(
        items,
        storeName: storeName,
        storeContact: storeContact,
        storeAddress: storeAddress,
      );
      _successMessage = 'Pesanan berhasil dibuat!';
      await loadMyOrders();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal membuat pesanan';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cancelOrder(String orderId) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _orderRepo.cancelOrder(orderId);
      _successMessage = 'Pesanan berhasil dibatalkan';
      await loadMyOrders();
      _isSubmitting = false;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _isSubmitting = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Gagal membatalkan pesanan';
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void clearMessages() {
    _errorMessage = null;
    _successMessage = null;
    notifyListeners();
  }
}
