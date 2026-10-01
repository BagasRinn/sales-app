import 'api_service.dart';
import '../models/bulletin.dart';

class BulletinRepository {
  final ApiService _api;
  BulletinRepository(this._api);

  Future<List<Bulletin>> getBulletins() async {
    final data = await _api.get('/bulletins');
    return (data as List).map((e) => Bulletin.fromJson(e)).toList();
  }

  Future<void> dismissBulletin(String bulletinId) async {
    await _api.post('/bulletins/$bulletinId/dismiss');
  }
}
