import 'package:flutter/foundation.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/models/customer.dart';

class CustomerProvider extends ChangeNotifier {
  final CustomerRepository _customerRepo;

  List<Customer> _customers = [];
  bool _isLoading = false;
  String? _error;

  CustomerProvider(this._customerRepo);

  List<Customer> get customers => _customers;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadCustomers({String? search}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _customers = await _customerRepo.getMyCustomers(search: search);
    } catch (e) {
      _error = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }
}
