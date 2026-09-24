import '../models/customer.dart';
import 'api_service.dart';

class CustomerRepository {
  final ApiService _api;

  CustomerRepository(this._api);

  Future<List<Customer>> getMyCustomers({String? search}) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) {
      queryParams['search'] = search;
    }
    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/customers/my$queryString');
    return (data as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
