import 'package:flutter/foundation.dart';
import '../../data/repositories/order_repository.dart';

class HomeStatsProvider extends ChangeNotifier {
  final OrderRepository _orderRepository;
  SalesStats? _stats;
  bool _loading = false;
  String? _errorMessage;

  HomeStatsProvider(this._orderRepository);

  SalesStats? get stats => _stats;
  bool get isLoading => _loading;
  String? get errorMessage => _errorMessage;

  Future<void> load() async {
    _loading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _stats = await _orderRepository.getMyStats();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await load();
  }
}
