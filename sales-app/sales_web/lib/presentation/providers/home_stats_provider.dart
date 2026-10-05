import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../data/models/order.dart';
import '../../data/repositories/order_repository.dart';

class HomeStatsProvider with ChangeNotifier {
  final OrderRepository _orderRepo;

  SalesStats? _stats;
  bool _isLoading = false;
  String? _error;

  HomeStatsProvider(this._orderRepo);

  SalesStats? get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _stats = await _orderRepo.getMyStats();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat statistik.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await load();
  }
}
