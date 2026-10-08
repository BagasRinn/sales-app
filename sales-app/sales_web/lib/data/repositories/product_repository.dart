import '../../core/api_service.dart';
import '../models/product.dart';

class ProductRepository {
  final ApiService _api;

  ProductRepository(this._api);

  Future<List<Product>> getProducts({
    int skip = 0,
    int limit = 3000,
    String? search,
    String? orderType,
  }) async {
    final params = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    if (orderType != null && orderType.isNotEmpty) {
      params['order_type'] = orderType;
    }
    final data = await _api.get('/products', queryParams: params);
    // /products returns a bare JSON array. The previous
    // `data['items'] ?? data as List` form threw on a List response because
    // `data['items']` raises before the `??` fallback is considered — list
    // indices must be int, not String. Type-check first.
    final list = data is List
        ? data
        : data is Map
            ? (data['items'] as List<dynamic>? ?? const <dynamic>[])
            : const <dynamic>[];
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<String>> get4pSuppliers() async {
    final data = await _api.get('/products/suppliers/4p');
    final list = data as List<dynamic>;
    return list.map((e) => e.toString()).toList();
  }
}
