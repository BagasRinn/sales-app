import 'package:flutter/foundation.dart';
import '../../data/models/product.dart';
import '../../data/repositories/product_repository.dart';
import '../../core/api_exception.dart';
import '../../core/design_system.dart';

enum ProductStatusFilter { all, available, low, outOfStock }

class ProductProvider extends ChangeNotifier {
  final ProductRepository _productRepo;
  static const int _pageSize = 1000;

  List<Product> _allProducts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;
  String _searchQuery = '';
  ProductStatusFilter _statusFilter = ProductStatusFilter.all;
  String? _categoryFilter;

  ProductProvider(this._productRepo);

  List<Product> get products {
    return _allProducts.where((p) {
      final statusMatch = _matchesStatusFilter(p);
      final categoryMatch = _matchesCategoryFilter(p);
      return statusMatch && categoryMatch;
    }).toList();
  }

  List<String> get availableCategories {
    final categories = _allProducts
        .where((p) => p.kategori != null && p.kategori!.isNotEmpty)
        .map((p) => p.kategori!)
        .toSet()
        .toList();
    categories.sort();
    return categories;
  }

  int get productCount => products.length;

  int countByStatus(ProductStatusFilter status) {
    return _allProducts.where((p) {
      final statusMatch = _matchesStatusFilterForCount(p, status);
      final categoryMatch = _matchesCategoryFilter(p);
      return statusMatch && categoryMatch;
    }).length;
  }

  int countByStatusAll(ProductStatusFilter status) {
    return _allProducts.where((p) {
      final s = stockStatusFromValue(p.stokTersedia);
      final categoryMatch = _matchesCategoryFilter(p);
      if (!categoryMatch) return false;
      switch (status) {
        case ProductStatusFilter.all:
          return true;
        case ProductStatusFilter.available:
          return s == StockStatus.available;
        case ProductStatusFilter.low:
          return s == StockStatus.low;
        case ProductStatusFilter.outOfStock:
          return s == StockStatus.outOfStock;
      }
    }).length;
  }

  int get totalFilteredCount {
    return _allProducts.where((p) {
      final statusMatch = _matchesStatusFilterForCount(p, _statusFilter);
      final categoryMatch = _matchesCategoryFilter(p);
      return statusMatch && categoryMatch;
    }).length;
  }

  bool _matchesStatusFilterForCount(Product p, ProductStatusFilter filter) {
    if (filter == ProductStatusFilter.all) return true;
    final status = stockStatusFromValue(p.stokTersedia);
    switch (filter) {
      case ProductStatusFilter.all:
        return true;
      case ProductStatusFilter.available:
        return status == StockStatus.available;
      case ProductStatusFilter.low:
        return status == StockStatus.low;
      case ProductStatusFilter.outOfStock:
        return status == StockStatus.outOfStock;
    }
  }

  bool _matchesStatusFilter(Product p) {
    if (_statusFilter == ProductStatusFilter.all) return true;
    final status = stockStatusFromValue(p.stokTersedia);
    switch (_statusFilter) {
      case ProductStatusFilter.all:
        return true;
      case ProductStatusFilter.available:
        return status == StockStatus.available;
      case ProductStatusFilter.low:
        return status == StockStatus.low;
      case ProductStatusFilter.outOfStock:
        return status == StockStatus.outOfStock;
    }
  }

  bool _matchesCategoryFilter(Product p) {
    if (_categoryFilter == null || _categoryFilter!.isEmpty) return true;
    return p.kategori == _categoryFilter;
  }

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  ProductStatusFilter get statusFilter => _statusFilter;
  String? get categoryFilter => _categoryFilter;

  Future<void> loadProducts({String? search}) async {
    _isLoading = true;
    _errorMessage = null;
    _hasMore = true;
    if (search != null) _searchQuery = search;
    notifyListeners();

    try {
      _allProducts = await _productRepo.getProducts(
        skip: 0,
        limit: _pageSize,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      _hasMore = _allProducts.length >= _pageSize;
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = 'Gagal memuat produk';
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMoreProducts() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      final moreProducts = await _productRepo.getProducts(
        skip: _allProducts.length,
        limit: _pageSize,
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );

      if (moreProducts.isEmpty) {
        _hasMore = false;
      } else {
        _allProducts.addAll(moreProducts);
        _hasMore = moreProducts.length >= _pageSize;
      }
    } on ApiException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      // Silent fail for load more
    }

    _isLoadingMore = false;
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

  void setStatusFilter(ProductStatusFilter filter) {
    if (_statusFilter == filter) return;
    _statusFilter = filter;
    _resetPagination();
    loadProducts();
  }

  void setCategoryFilter(String? category) {
    if (_categoryFilter == category) return;
    _categoryFilter = category;
    _resetPagination();
    loadProducts();
  }

  void clearFilters() {
    _statusFilter = ProductStatusFilter.all;
    _categoryFilter = null;
    _searchQuery = '';
    _resetPagination();
    loadProducts();
  }

  void _resetPagination() {
    _allProducts = [];
    _hasMore = true;
  }

  bool get hasActiveFilters =>
      _statusFilter != ProductStatusFilter.all || _categoryFilter != null;
}
