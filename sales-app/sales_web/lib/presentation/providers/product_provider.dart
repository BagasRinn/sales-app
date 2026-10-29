import 'package:flutter/foundation.dart';
import '../../core/api_exception.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';

enum StockStatus { available, low, outOfStock }

StockStatus getStockStatus(int available) {
  if (available <= 0) return StockStatus.outOfStock;
  if (available <= 5) return StockStatus.low;
  return StockStatus.available;
}

class ProductProvider with ChangeNotifier {
  final ProductRepository _productRepo;
  // Muat produk per halaman (50/item), bukan semua sekaligus (3000).
  static const int _pageSize = 50;
  // Cache produk selama 5 menit untuk mencegah reload berulang.
  static const Duration _productCacheDuration = Duration(minutes: 5);

  List<Product> _allProducts = [];
  List<String> _suppliers4p = [];
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  String? _orderTypeFilter;
  DateTime? _lastLoadTime;

  ProductProvider(this._productRepo);

  List<Product> get allProducts => _allProducts;
  List<String> get suppliers4p => _suppliers4p;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// Cek apakah cache produk masih valid (belum lewat durasi cache).
  bool get _isProductCacheValid {
    if (_lastLoadTime == null || _allProducts.isEmpty) return false;
    return DateTime.now().difference(_lastLoadTime!) < _productCacheDuration;
  }

  List<Product> get filteredProducts {
    var products = _allProducts;
    if (_orderTypeFilter != null && _orderTypeFilter!.isNotEmpty) {
      products = products.where((p) => p.orderType == _orderTypeFilter).toList();
    }
    return products;
  }

  Future<void> loadProducts({String? search, String? orderType}) async {
    // Jika cache masih valid dan tidak ada search/orderType baru, skip reload.
    if (_isProductCacheValid && search == null && orderType == null) {
      return;
    }

    _isLoading = true;
    _error = null;
    _searchQuery = search ?? '';
    notifyListeners();

    try {
      _allProducts = await _productRepo.getProducts(
        skip: 0,
        limit: _pageSize,
        search: search,
        orderType: orderType,
      );
      _lastLoadTime = DateTime.now();
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Gagal memuat produk.';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreProducts() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      final moreProducts = await _productRepo.getProducts(
        skip: _allProducts.length,
        limit: _pageSize,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
        orderType: _orderTypeFilter,
      );
      if (moreProducts.isEmpty) {
        // No more products
      } else {
        _allProducts.addAll(moreProducts);
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      // Silent fail for load more
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

  void search(String query) {
    if (query == _searchQuery) return;
    _searchQuery = query;
    _lastLoadTime = null;
    loadProducts(search: query);
  }

  void clearSearch() {
    if (_searchQuery.isEmpty) return;
    _searchQuery = '';
    _lastLoadTime = null;
    loadProducts();
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
