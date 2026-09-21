import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../core/api_exception.dart';

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepo;
  final _currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

  List<Product> _products = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';

  ProductProvider(this._productRepo);

  List<Product> get products => _products;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;

  /// Cached currency formatter — avoids ICU initialization per card
  String formatCurrency(int amount) => _currencyFormat.format(amount);

  Future<void> loadProducts({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    if (search != null) _searchQuery = search;
    notifyListeners();

    try {
      _products = await _productRepo.getProducts(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Gagal memuat produk';
    }

    _isLoading = false;
    notifyListeners();
  }

  void search(String query) {
    _searchQuery = query;
    loadProducts();
  }

  void clearSearch() {
    _searchQuery = '';
    loadProducts();
  }
}
