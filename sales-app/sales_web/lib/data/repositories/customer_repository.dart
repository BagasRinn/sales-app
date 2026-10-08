import '../../core/api_service.dart';
import '../models/customer.dart';
import '../models/customer_submission.dart';

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

  Future<CustomerSubmission> submitCustomerRegistration(Map<String, dynamic> payload) async {
    final data = await _api.post('/customer-submissions', body: payload);
    return CustomerSubmission.fromJson(data as Map<String, dynamic>);
  }

  Future<void> cancelSubmission(String submissionId) async {
    await _api.post('/customer-submissions/$submissionId/cancel', body: {});
  }

  Future<List<CustomerSubmission>> getMyCustomerSubmissions() async {
    final data = await _api.get('/customer-submissions/my');
    return (data as List)
        .map((e) => CustomerSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> checkDuplicateCustomer({
    required String name,
    String alamat = '',
  }) async {
    final queryParams = <String, String>{'name': name};
    if (alamat.isNotEmpty) queryParams['alamat'] = alamat;
    final data = await _api.get(
      '/customer-submissions/check-duplicate',
      queryParams: queryParams,
    );
    return data as Map<String, dynamic>;
  }

  Future<List<String>> getKodeAreas() async {
    final data = await _api.get('/customers/kode-areas');
    final items = (data as Map<String, dynamic>)['items'] as List? ?? [];
    return items.map((e) => e as String).toList();
  }
}
