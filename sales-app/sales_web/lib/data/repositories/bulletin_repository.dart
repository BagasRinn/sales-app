import '../../core/api_service.dart';
import '../models/bulletin.dart';

class BulletinRepository {
  final ApiService _api;

  BulletinRepository(this._api);

  Future<List<Bulletin>> getBulletins({bool includeRead = true}) async {
    final data = await _api.get('/bulletins', queryParams: {
      'include_read': includeRead.toString(),
    });
    final list = data is List ? data : (data['items'] ?? data);
    return (list as List).map((e) => Bulletin.fromJson(e)).toList();
  }

  Future<void> markAsRead(String bulletinId) async {
    await _api.post('/bulletins/$bulletinId/dismiss');
  }
}
