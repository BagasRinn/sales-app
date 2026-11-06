import '../models/customer.dart';
import '../models/customer_submission.dart';
import 'api_service.dart';

class CustomerRepository {
  final ApiService _api;

  /// Cache list customer tanpa filter. Dipakai order flow agar membuka form
  /// order berulang kali tidak menarik ~2.000 customer lagi dari Postgres.
  static const Duration _cacheTtl = Duration(minutes: 10);
  List<Customer>? _cachedCustomers;
  DateTime? _cachedAt;
  String? _cachedToken;

  CustomerRepository(this._api);

  bool get _isCacheValid {
    if (_cachedCustomers == null || _cachedAt == null) return false;
    // Jangan bagikan cache lintas sesi/login di perangkat yang sama.
    if (_cachedToken != _api.accessToken) return false;
    return DateTime.now().difference(_cachedAt!) < _cacheTtl;
  }

  /// Hapus cache setelah data customer berubah (mis. setelah approval admin).
  void invalidateCache() {
    _cachedCustomers = null;
    _cachedAt = null;
    _cachedToken = null;
  }

  Future<List<Customer>> getMyCustomers({String? search}) async {
    final query = (search ?? '').trim();
    if (query.isEmpty && _isCacheValid) {
      return List<Customer>.unmodifiable(_cachedCustomers!);
    }

    final queryParams = <String, String>{};
    if (query.isNotEmpty) {
      queryParams['search'] = query;
    }
    final queryString = queryParams.isEmpty
        ? ''
        : '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/customers/my$queryString');
    final result = (data as List)
        .map((e) => Customer.fromJson(e as Map<String, dynamic>))
        .toList();

    if (query.isEmpty) {
      _cachedCustomers = result;
      _cachedAt = DateTime.now();
      _cachedToken = _api.accessToken;
    }
    return result;
  }

  /// Submit pengajuan customer baru ke backend. Status langsung PENDING.
  /// Caller is responsible for setting `bareng_order`, `order_type`, and
  /// `order_items` fields in [payload] when bundling an order.
  Future<CustomerSubmission> submitCustomerRegistration(
    Map<String, dynamic> payload,
  ) async {
    final data = await _api.post('/customer-submissions', body: payload);
    return CustomerSubmission.fromJson(data);
  }

  /// Cancel a pending customer submission.
  Future<void> cancelSubmission(String submissionId) async {
    await _api.post(
      '/customer-submissions/$submissionId/cancel',
      body: {},
    );
  }

  /// Sales lihat history submission sendiri (semua status, urut terbaru).
  Future<List<CustomerSubmission>> getMyCustomerSubmissions() async {
    final data = await _api.get('/customer-submissions/my');
    return (data as List)
        .map((e) => CustomerSubmission.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Cek duplicate nama+alamat di customer existing.
  /// Return Map {has_duplicate: bool, matches: List<Map>}.
  Future<Map<String, dynamic>> checkDuplicateCustomer({
    required String name,
    String alamat = '',
  }) async {
    final queryParams = <String, String>{
      'name': name,
    };
    if (alamat.isNotEmpty) {
      queryParams['alamat'] = alamat;
    }
    final queryString = '?${queryParams.entries.map((e) => '${e.key}=${e.value}').join('&')}';
    final data = await _api.get('/customer-submissions/check-duplicate$queryString');
    return data as Map<String, dynamic>;
  }

  /// List distinct kode_area dari backend — sumber dropdown 'Kode Area'
  /// di form pengajuan customer baru. Empty list artinya belum ada area
  /// terdaftar; sales tetap bisa ketik manual via "Lainnya..." di form.
  Future<List<String>> getKodeAreas() async {
    final data = await _api.get('/customers/kode-areas');
    final items = (data as Map<String, dynamic>)['items'] as List? ?? [];
    return items.map((e) => e as String).toList();
  }
}
