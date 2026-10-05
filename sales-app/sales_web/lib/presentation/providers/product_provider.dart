import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

class ProductProvider with ChangeNotifier {
  final ProductRepository _productRepo;

  List<Product> _allProducts = [];
  List<String> _suppliers4p = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _orderTypeFilter;

  ProductProvider(this._productRepo);

  List<Product> get allProducts => _allProducts;
  List<String> get suppliers4p => _suppliers4p;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  List<Product> get filteredProducts {
    var products = _allProducts;
    if (_orderTypeFilter != null && _orderTypeFilter!.isNotEmpty) {
      products = products.where((p) => p.orderType == _orderTypeFilter).toList();
    }
    return products;
  }

  Future<void> loadProducts({String? search, String? orderType}) async {
    _isLoading = true;
    _error = null;
    _searchQuery = search ?? '';
    notifyListeners();

    try {
      _allProducts = await _productRepo.getProducts(
        search: search,
        orderType: orderType,
        limit: 3000,
      );
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat produk.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSuppliers4p() async {
    if (_suppliers4p.isNotEmpty) return;
    try {
      _suppliers4p = await _productRepo.get4pSuppliers();
      notifyListeners();
    } catch (_) {}
  }

  void setOrderTypeFilter(String? type) {
    _orderTypeFilter = type;
    notifyListeners();
  }

  int countByStockStatus(StockStatus status) {
    return _allProducts.where((p) {
      final avail = p.stokTersedia;
      if (status == StockStatus.available) return avail > 5;
      if (status == StockStatus.low) return avail > 0 && avail <= 5;
      return avail <= 0;
    }).length;
  }
}

enum StockStatus { available, low, outOfStock }

StockStatus getStockStatus(int available) {
  if (available <= 0) return StockStatus.outOfStock;
  if (available <= 5) return StockStatus.low;
  return StockStatus.available;
}
