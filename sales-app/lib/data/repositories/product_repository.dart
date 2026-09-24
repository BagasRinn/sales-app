import '../models/product.dart';
import 'api_service.dart';

class ProductRepository {
  final ApiService _api;

  ProductRepository(this._api);

  Future<List<Product>> getProducts({
    int skip = 0,
    int limit = 50,
    String? search,
  }) async {
    final queryParams = <String, String>{
      'skip': skip.toString(),
      'limit': limit.toString(),
    };
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }

    final data = await _api.get('/products', queryParams: queryParams);
    return (data as List).map((e) => Product.fromJson(e)).toList();
  }

  Future<Product> getProduct(String productId) async {
    final data = await _api.get('/products/$productId');
    return Product.fromJson(data);
  }
}
