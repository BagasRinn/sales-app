import '../models/product.dart';
import 'api_service.dart';

class ProductRepository {
  final ApiService _api;

  ProductRepository(this._api);

  Future<List<Product>> getProducts({
    int skip = 0,
    int limit = 50,
    String? search,
    String? orderType,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    if (orderType != null && orderType.isNotEmpty) {
      queryParams['order_type'] = orderType;
    }

    final data = await _api.get('/products', queryParams: queryParams);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<List<String>> get4pSuppliers() async {
    final data = await _api.get('/products/suppliers/4p');
    return (data as List).map((e) => e.toString()).toList();
  }

  Future<Product> getProduct(String productId) async {
    final data = await _api.get('/products/$productId');
    return Product.fromJson(data);
  }
}
