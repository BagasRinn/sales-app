import '../../core/api_service.dart';
import '../models/customer.dart';

class CustomerRepository {
  final ApiService _api;

  CustomerRepository(this._api);

  Future<List<Customer>> getMyCustomers({String? search}) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) {
      params['search'] = search;
    }
    final data = await _api.get('/customers/my', queryParams: params.isEmpty ? null : params);
    final list = data as List<dynamic>;
    return list.map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
  }
}
